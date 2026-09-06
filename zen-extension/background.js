"use strict";

const endpoint = "http://127.0.0.1:47616/v1/events";
let retry;

function connect() {
  const events = new EventSource(endpoint);
  events.onmessage = async event => {
    try {
      await browser.theme.update(paletteToTheme(JSON.parse(event.data)));
    } catch (error) {
      console.error("[ryoku-zen-palette] rejected palette", error);
    }
  };
  events.onerror = () => {
    events.close();
    clearTimeout(retry);
    retry = setTimeout(connect, 3000);
  };
}

connect();
