#!/usr/bin/env node
// Map serve-sim accessibility frames to the browser mirror coordinate space.

const DEFAULT_BASE_URL = "http://127.0.0.1:3200";

const args = parseArgs(process.argv.slice(2));

if (args.help) {
  printUsage();
  process.exit(0);
}

const baseUrl = args.baseUrl || DEFAULT_BASE_URL;

try {
  const api = await fetchJson(new URL("/api", baseUrl));
  const axUrl = new URL(api.axEndpoint || "/ax", baseUrl);
  const snapshot = await fetchAxSnapshot(axUrl);
  const elements = flattenElements(snapshot.elements || []);
  const filtered = filterElements(elements, args.filter);
  const limited = Number.isFinite(args.limit) ? filtered.slice(0, args.limit) : filtered;
  const frame = args.frame;

  if (args.json) {
    const payload = {
      screen: snapshot.screen,
      browserFrame: frame || null,
      elements: limited.map((element) => formatElement(element, snapshot.screen, frame)),
    };
    console.log(JSON.stringify(payload, null, 2));
  } else {
    printTextReport(limited, snapshot.screen, frame, baseUrl);
  }
} catch (error) {
  console.error(`simulator-browser-ax-map: ${error.message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const parsed = {
    baseUrl: null,
    filter: "",
    frame: null,
    help: false,
    json: false,
    limit: Number.POSITIVE_INFINITY,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "-h" || arg === "--help") {
      parsed.help = true;
    } else if (arg === "--json") {
      parsed.json = true;
    } else if (arg === "--base-url") {
      parsed.baseUrl = requireValue(argv, (index += 1), arg);
    } else if (arg === "--filter") {
      parsed.filter = requireValue(argv, (index += 1), arg);
    } else if (arg === "--frame") {
      parsed.frame = parseFrame(requireValue(argv, (index += 1), arg));
    } else if (arg === "--limit") {
      parsed.limit = parsePositiveInteger(requireValue(argv, (index += 1), arg), arg);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function requireValue(argv, index, arg) {
  if (index >= argv.length) {
    throw new Error(`${arg} requires a value`);
  }
  return argv[index];
}

function parsePositiveInteger(value, arg) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`${arg} must be a positive integer`);
  }
  return number;
}

function parseFrame(value) {
  const parts = value.split(",").map((part) => Number(part.trim()));
  if (parts.length !== 4 || parts.some((part) => !Number.isFinite(part))) {
    throw new Error("--frame must be left,top,width,height");
  }

  const [left, top, width, height] = parts;
  if (width <= 0 || height <= 0) {
    throw new Error("--frame width and height must be greater than zero");
  }

  return { left, top, width, height };
}

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`GET ${url} failed with ${response.status}`);
  }
  return response.json();
}

async function fetchAxSnapshot(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) {
      throw new Error(`GET ${url} failed with ${response.status}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }

      buffer += decoder.decode(value, { stream: true });
      const event = readFirstServerSentEvent(buffer);
      if (event) {
        await reader.cancel();
        return JSON.parse(event);
      }
    }

    const event = readFirstServerSentEvent(buffer);
    if (event) {
      return JSON.parse(event);
    }

    throw new Error(`No accessibility payload received from ${url}`);
  } finally {
    clearTimeout(timeout);
  }
}

function readFirstServerSentEvent(buffer) {
  const events = buffer.split(/\n\n/);
  for (const event of events) {
    const dataLines = event
      .split(/\n/)
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice("data:".length).trimStart());

    if (dataLines.length > 0) {
      return dataLines.join("\n");
    }
  }

  return null;
}

function flattenElements(elements, depth = 0) {
  const result = [];
  for (const element of elements) {
    result.push({ ...element, depth });
    if (Array.isArray(element.children) && element.children.length > 0) {
      result.push(...flattenElements(element.children, depth + 1));
    }
  }
  return result;
}

function filterElements(elements, query) {
  const normalizedQuery = query.trim().toLowerCase();
  const visibleElements = elements.filter((element) => {
    const frame = element.frame;
    return frame && frame.width > 0 && frame.height > 0;
  });

  if (!normalizedQuery) {
    return visibleElements;
  }

  return visibleElements.filter((element) => {
    const haystack = [
      element.label,
      element.id,
      element.path,
      element.role,
      element.type,
      element.value,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    return haystack.includes(normalizedQuery);
  });
}

function formatElement(element, screen, browserFrame) {
  const simulator = normalizeRect(element.frame);
  return {
    label: element.label || "",
    id: element.id || "",
    path: element.path || "",
    role: element.role || element.type || "",
    simulator,
    simulatorCenter: center(simulator),
    browser: browserFrame ? mapRect(simulator, screen, browserFrame) : null,
    browserCenter: browserFrame ? center(mapRect(simulator, screen, browserFrame)) : null,
  };
}

function normalizeRect(rect) {
  return {
    x: round(rect.x),
    y: round(rect.y),
    width: round(rect.width),
    height: round(rect.height),
  };
}

function mapRect(rect, screen, browserFrame) {
  const scaleX = browserFrame.width / screen.width;
  const scaleY = browserFrame.height / screen.height;
  return {
    x: round(browserFrame.left + rect.x * scaleX),
    y: round(browserFrame.top + rect.y * scaleY),
    width: round(rect.width * scaleX),
    height: round(rect.height * scaleY),
  };
}

function center(rect) {
  return {
    x: round(rect.x + rect.width / 2),
    y: round(rect.y + rect.height / 2),
  };
}

function round(value) {
  return Math.round(value * 10) / 10;
}

function printTextReport(elements, screen, browserFrame, baseUrl) {
  console.log(`AX source: ${baseUrl}`);
  console.log(`Simulator screen: ${screen.width} x ${screen.height} pt`);
  if (browserFrame) {
    console.log(
      `Browser frame: left=${browserFrame.left}, top=${browserFrame.top}, width=${browserFrame.width}, height=${browserFrame.height}`,
    );
  } else {
    console.log("Browser frame: not provided; showing simulator-point frames only");
  }
  console.log("");

  for (const element of elements) {
    const formatted = formatElement(element, screen, browserFrame);
    const label = formatted.label || formatted.id || formatted.path || "(unlabeled)";
    console.log(`${label} [${formatted.role}]`);
    console.log(
      `  sim rect: x=${formatted.simulator.x}, y=${formatted.simulator.y}, w=${formatted.simulator.width}, h=${formatted.simulator.height}; center=${formatted.simulatorCenter.x},${formatted.simulatorCenter.y}`,
    );
    if (formatted.browser) {
      console.log(
        `  browser rect: x=${formatted.browser.x}, y=${formatted.browser.y}, w=${formatted.browser.width}, h=${formatted.browser.height}; center=${formatted.browserCenter.x},${formatted.browserCenter.y}`,
      );
    }
  }
}

function printUsage() {
  console.log(`Usage:
  Pillie/scripts/simulator-browser-ax-map.mjs [options]

Options:
  --base-url URL          serve-sim browser URL. Default: ${DEFAULT_BASE_URL}
  --frame L,T,W,H         Browser simulator frame from getBoundingClientRect()
  --filter TEXT           Only print matching labels, ids, paths, roles, or types
  --limit N               Limit printed elements
  --json                  Emit JSON
  -h, --help              Show this help

Example:
  Pillie/scripts/simulator-browser-ax-map.mjs --filter "Upgrade" --frame 326,121.8,525,1141.4
`);
}
