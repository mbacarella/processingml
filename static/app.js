/* ProcessingML playground: editor, toplevel bootstrap, console, canvas. */

(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const consoleEl = $("console");
  const bootEl = $("boot");
  const bootText = $("boot-text");

  /* ------------------------------------------------------------ console */

  let lastKind = null;
  let lastSpan = null;

  function write(kind, text) {
    if (!text) return;
    if (kind !== lastKind || !lastSpan) {
      lastSpan = document.createElement("span");
      lastSpan.className = kind;
      consoleEl.appendChild(lastSpan);
      lastKind = kind;
    }
    lastSpan.appendChild(document.createTextNode(text));
    // Keep the console from growing without bound during a chatty draw loop.
    while (consoleEl.childNodes.length > 400) consoleEl.removeChild(consoleEl.firstChild);
    consoleEl.scrollTop = consoleEl.scrollHeight;
  }

  function separator(label) {
    const el = document.createElement("span");
    el.className = "run-sep";
    el.textContent = label;
    consoleEl.appendChild(el);
    lastKind = null;
    lastSpan = null;
    consoleEl.scrollTop = consoleEl.scrollHeight;
  }

  function clearConsole() {
    consoleEl.textContent = "";
    lastKind = null;
    lastSpan = null;
  }

  function toast(message) {
    const el = document.createElement("div");
    el.className = "toast";
    el.textContent = message;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 1800);
  }

  /* ------------------------------------------------------------- editor */

  const textarea = $("code");
  let editor = null;

  function getCode() {
    return editor ? editor.getValue() : textarea.value;
  }

  function setCode(code) {
    if (editor) editor.setValue(code);
    else textarea.value = code;
  }

  function initEditor(initial) {
    textarea.value = initial;
    if (typeof CodeMirror === "undefined") return; // CDN blocked: plain textarea
    editor = CodeMirror.fromTextArea(textarea, {
      mode: "text/x-ocaml",
      lineNumbers: true,
      matchBrackets: true,
      autoCloseBrackets: true,
      indentUnit: 2,
      tabSize: 2,
      lineWrapping: false,
      extraKeys: {
        "Ctrl-Enter": run,
        "Cmd-Enter": run,
        Tab: (cm) => cm.execCommand("indentMore"),
        "Shift-Tab": (cm) => cm.execCommand("indentLess"),
      },
    });
    editor.on("change", saveSoon);
  }

  /* ----------------------------------------------------- code persistence */

  const STORAGE_KEY = "processingml.code";

  const encode = (s) =>
    btoa(String.fromCharCode(...new TextEncoder().encode(s)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const decode = (s) => {
    const b = atob(s.replace(/-/g, "+").replace(/_/g, "/"));
    return new TextDecoder().decode(Uint8Array.from(b, (c) => c.charCodeAt(0)));
  };

  let saveTimer = null;
  function saveSoon() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try {
        localStorage.setItem(STORAGE_KEY, getCode());
      } catch (_) {
        /* private mode, quota, … — not worth bothering the user about */
      }
    }, 400);
  }

  function initialCode() {
    const hash = location.hash.replace(/^#code=/, "");
    if (location.hash.startsWith("#code=")) {
      try {
        return decode(hash);
      } catch (_) {
        /* fall through */
      }
    }
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) return saved;
    } catch (_) {
      /* ignore */
    }
    return window.EXAMPLES[0].code;
  }

  /* ----------------------------------------------------------- toplevel */

  let ready = false;

  function run() {
    if (!ready) return;
    const code = getCode();
    saveSoon();
    separator("▶ run · " + new Date().toLocaleTimeString());
    try {
      OCamlTop.exec(code, true);
    } catch (e) {
      write("err", "Internal error: " + e + "\n");
    }
  }

  function stop() {
    if (!ready) return;
    OCamlTop.noLoop();
  }

  /* The console is a real toplevel prompt: it evaluates in the same session as
     the editor, and without resetting the canvas, so you can poke at a running
     sketch. */
  const history = [];
  let historyAt = 0;

  function initRepl() {
    const input = $("repl");
    $("repl-form").addEventListener("submit", (e) => {
      e.preventDefault();
      const line = input.value.trim();
      if (!ready || !line) return;
      history.push(line);
      historyAt = history.length;
      input.value = "";
      write("prompt", "# " + line + "\n");
      try {
        OCamlTop.exec(line, false);
      } catch (err) {
        write("err", "Internal error: " + err + "\n");
      }
    });
    input.addEventListener("keydown", (e) => {
      if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
      if (!history.length) return;
      e.preventDefault();
      historyAt += e.key === "ArrowUp" ? -1 : 1;
      historyAt = Math.max(0, Math.min(history.length, historyAt));
      input.value = history[historyAt] || "";
    });
  }

  function reset() {
    if (!ready) return;
    OCamlTop.reset();
    separator("· canvas reset");
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.onload = resolve;
      script.onerror = () => reject(new Error("could not load " + src));
      document.head.appendChild(script);
    });
  }

  /* Streaming the file ourselves only buys a progress readout, and fetch() is
     blocked on file:// — so fall back to a plain script tag whenever it is not
     available. The playground works either way. */
  async function fetchWithProgress() {
    const response = await fetch("toplevel.js");
    if (!response.ok) throw new Error("HTTP " + response.status);

    const total = Number(response.headers.get("content-length")) || 0;
    const chunks = [];
    let received = 0;
    const reader = response.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      received += value.length;
      const mb = (received / 1048576).toFixed(1);
      bootText.textContent = total
        ? `Downloading the OCaml toplevel… ${mb} / ${(total / 1048576).toFixed(1)} MB`
        : `Downloading the OCaml toplevel… ${mb} MB`;
    }

    bootText.textContent = "Starting the toplevel…";
    const url = URL.createObjectURL(new Blob(chunks, { type: "text/javascript" }));
    try {
      await loadScript(url);
    } finally {
      URL.revokeObjectURL(url);
    }
  }

  async function loadToplevel() {
    if (location.protocol === "file:") {
      bootText.textContent = "Loading the OCaml toplevel…";
      await loadScript("toplevel.js");
    } else {
      try {
        await fetchWithProgress();
      } catch (e) {
        bootText.textContent = "Loading the OCaml toplevel…";
        await loadScript("toplevel.js");
      }
    }

    OCamlTop.setSink(write);
    const version = OCamlTop.init();
    $("version").textContent = "OCaml " + version + " · js_of_ocaml";
    ready = true;
    bootEl.classList.add("hidden");
  }

  /* ------------------------------------------------------------ splitter */

  function initSplitter() {
    const splitter = $("splitter");
    const layout = $("layout");
    splitter.addEventListener("pointerdown", (down) => {
      if (window.matchMedia("(max-width: 900px)").matches) return;
      down.preventDefault();
      splitter.setPointerCapture(down.pointerId);
      const onMove = (move) => {
        const min = 260;
        const max = layout.clientWidth - 320;
        const w = Math.max(min, Math.min(max, move.clientX - layout.offsetLeft));
        layout.style.setProperty("--split", w + "px");
        if (editor) editor.refresh();
      };
      const onUp = () => {
        splitter.removeEventListener("pointermove", onMove);
        splitter.removeEventListener("pointerup", onUp);
      };
      splitter.addEventListener("pointermove", onMove);
      splitter.addEventListener("pointerup", onUp);
    });
  }

  /* ---------------------------------------------------------------- wire */

  function initExamples() {
    const select = $("examples");
    window.EXAMPLES.forEach((example, i) => {
      const option = document.createElement("option");
      option.value = String(i);
      option.textContent = example.name;
      select.appendChild(option);
    });
    select.addEventListener("change", () => {
      const i = Number(select.value);
      if (!select.value) return;
      setCode(window.EXAMPLES[i].code);
      select.value = "";
      saveSoon();
      run();
    });
  }

  function share() {
    const url =
      location.origin + location.pathname + "#code=" + encode(getCode());
    history.replaceState(null, "", url);
    navigator.clipboard
      .writeText(url)
      .then(() => toast("Link copied to the clipboard"))
      .catch(() => toast("Link is in the address bar"));
  }

  function init() {
    initEditor(initialCode());
    initExamples();
    initSplitter();
    initRepl();

    $("run").addEventListener("click", run);
    $("stop").addEventListener("click", stop);
    $("reset").addEventListener("click", reset);
    $("share").addEventListener("click", share);
    $("clear-console").addEventListener("click", clearConsole);
    $("ref-toggle").addEventListener("click", () => {
      $("reference").hidden = !$("reference").hidden;
    });
    $("ref-close").addEventListener("click", () => {
      $("reference").hidden = true;
    });

    document.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        run();
      }
    });

    loadToplevel()
      .then(() => run())
      .catch((e) => {
        bootText.textContent = "Could not load the toplevel: " + e.message;
        bootEl.querySelector(".spinner").style.display = "none";
      });
  }

  init();
})();
