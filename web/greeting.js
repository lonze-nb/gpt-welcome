const defaultGreeting = "welcome";
const svgSpace = "http://www.w3.org/2000/svg";
const ink = ["#36a9be", "#6fbf84", "#e5af2c", "#f17b56", "#df70aa", "#8260c5", "#3b8bc6"];
const activeDrawings = new WeakMap();

function svgNode(tag, attributes = {}) {
  const node = document.createElementNS(svgSpace, tag);
  for (const [name, value] of Object.entries(attributes)) node.setAttribute(name, value);
  return node;
}

function glyph(character) {
  const latin = letterStrokes[character];
  if (latin) {
    const [width, ...paths] = latin;
    return { width, paths: paths.flatMap(path => path.split(/(?=M)/)), weight: 5.8, joins: /^[a-z]$/.test(character) };
  }
  const hanzi = hanziStrokes[character];
  if (hanzi) {
    const paths = hanzi.map(points => points.map(([x, y], index) => {
      return (index ? "L" : "M") + (x * .077).toFixed(1) + " " + ((900 - y) * .077 + 10).toFixed(1);
    }).join(" "));
    return { width: 85, paths, weight: 5.2 };
  }
  if (/^\s+$/u.test(character)) return { width: 24 };
  return { width: 68, character };
}

function renderGreeting(element, greeting) {
  activeDrawings.get(element)?.();
  element.setAttribute("aria-label", greeting);
  const characters = Array.from(new Intl.Segmenter().segment(greeting), item => item.segment);
  const lines = [{ width: 0, glyphs: [] }];
  for (const character of characters) {
    const next = glyph(character);
    let line = lines.at(-1);
    if (line.width + next.width > 790) {
      line = { width: 0, glyphs: [] };
      lines.push(line);
    }
    if (!line.width && !next.paths && !next.character) continue;
    line.glyphs.push(next);
    line.width += next.width;
  }
  const width = Math.max(360, ...lines.map(line => line.width + 36));
  const artwork = svgNode("svg", {
    "aria-hidden": "true",
    viewBox: `0 0 ${width} ${lines.length * 103 + 20}`,
  });
  element.replaceChildren(artwork);
  const strokes = [];
  let drawn = 0;
  const totalGlyphs = lines.reduce((total, line) =>
    total + line.glyphs.filter(item => item.paths || item.character).length, 0);

  for (const [index, line] of lines.entries()) {
    let x = (width - line.width) / 2;
    let previous = null;
    const row = svgNode("g", { transform: `translate(0 ${10 + index * 103})` });
    artwork.append(row);
    for (const item of line.glyphs) {
      if (item.paths) {
        const color = ink[Math.round(drawn / Math.max(totalGlyphs - 1, 1) * (ink.length - 1))];
        const group = svgNode("g", {
          transform: `translate(${x} 0)`, fill: "none", stroke: color,
          "stroke-width": item.weight, "stroke-linecap": "round", "stroke-linejoin": "round",
        });
        const paths = item.paths.map(d => svgNode("path", { d }));
        group.append(...paths);
        row.append(group);
        const start = paths[0].getPointAtLength(0);
        if (item.joins && previous && start.x < 9 && start.y > 48) {
          const fromX = previous.x - x;
          const join = svgNode("path", {
            d: `M${fromX} ${previous.y} Q${(fromX + start.x) / 2} ${(previous.y + start.y) / 2 + 4} ${start.x} ${start.y}`,
          });
          group.prepend(join);
          strokes.push(join);
        }
        strokes.push(...paths);
        const end = paths[0].getPointAtLength(paths[0].getTotalLength());
        previous = item.joins && end.x > item.width * .65 && end.y > 48
          ? { x: x + end.x, y: end.y } : null;
        drawn++;
      } else {
        previous = null;
        if (item.character) {
          const text = svgNode("text", { x: x + item.width / 2, y: 76, "text-anchor": "middle", "font-size": 53, fill: ink[drawn % ink.length] });
          text.textContent = item.character;
          row.append(text);
          strokes.push(text);
          drawn++;
        }
      }
      x += item.width;
    }
  }
  return strokes;
}

function showGreeting(element, greeting) {
  renderGreeting(element, greeting);
}

function animateGreeting(element, greeting) {
  const strokes = renderGreeting(element, greeting);
  if (matchMedia("(prefers-reduced-motion: reduce)").matches || !strokes.length) return Promise.resolve();

  let total = 0;
  const timeline = strokes.map(node => {
    const isPath = node.localName === "path";
    const length = isPath ? Math.max(.5, node.getTotalLength()) : 35;
    const step = { node, isPath, length, start: total };
    total += length + 5;
    if (isPath) {
      node.style.strokeDasharray = `${length} ${length + 1}`;
      node.style.strokeDashoffset = length;
    }
    node.style.visibility = "hidden";
    return step;
  });

  const duration = Math.min(5600, Math.max(1500, 2150 + (total - 650) * 1.45));
  return new Promise(resolve => {
    let frame = 0;
    let started;
    let current = 0;
    function finish() {
      cancelAnimationFrame(frame);
      activeDrawings.delete(element);
      resolve();
    }
    function draw(now) {
      started ??= now;
      const progress = Math.min(1, (now - started) / duration);
      const distance = total * (progress * progress * (3 - 2 * progress));
      while (current < timeline.length) {
        const { node, isPath, length, start } = timeline[current];
        if (distance <= start) break;
        const fraction = Math.min(1, (distance - start) / length);
        node.style.visibility = "visible";
        if (isPath) node.style.strokeDashoffset = length * (1 - fraction);
        else node.style.opacity = fraction;
        if (fraction < 1) break;
        current++;
      }
      if (progress < 1) frame = requestAnimationFrame(draw);
      else finish();
    }
    activeDrawings.set(element, finish);
    frame = requestAnimationFrame(draw);
  });
}
