// xtrapartial's website: one screen, drawn small and blown up in hard
// pixels like the game's 3D (360 lines, point-filtered), with the game's
// boxes: white cards with a crooked black frame set in from the edge
// (src/ui/paper_box.gd). The words and buttons come from the page's HTML,
// which stays over the canvas unseen so links, the keyboard and screen
// readers work.
//
// - The background dithers from black to maroon in 16-bit colour, like
//   the game's optional colours mode.
// - A blob hangs upside down from the top, swinging. Hover a download and
//   it jolts.
// - The picture card flips through screenshots (data-shots) with the
//   game's box wipe, or low-res stand-ins until there are some.
// - A download without an address yet says "soon :)".

(function () {
	"use strict";

	const still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	const screen = document.getElementById("screen");
	const canvas = document.getElementById("pixels");
	const ctx = canvas.getContext("2d");
	const status = document.getElementById("status");
	const FONT = '"Liberation Sans", Arial, Helvetica, sans-serif';
	const INK = "#0d0d0f";
	const PAPER = "#ffffff";
	const GREY = "#8c8c94";
	const PINK = "#ff3d73";
	// The layout wide screens get, in canvas pixels; narrower ones stack,
	// on a canvas about TALL_LOW pixels across. Each canvas pixel is a
	// whole number of screen pixels, and type sits on whole pixels.
	const DESIGN = { w: 400, h: 222 };
	const TALL_LOW = 180;
	const SLIDE_TIME = 5.0;
	const WIPE_TIME = 0.5;

	// --- The page's words ----------------------------------------------------

	const logoEl = document.querySelector('[data-card="logo"]');
	const infoEl = document.querySelector('[data-card="info"]');
	const picsEl = document.querySelector('[data-card="pictures"]');
	const logoText = logoEl.querySelector("h1").textContent.trim();
	const lines = Array.from(infoEl.querySelectorAll("li"), (li) => li.textContent.trim());
	const caption = picsEl.querySelector(".caption");
	const shots = (picsEl.getAttribute("data-shots") || "").split(",").map((s) => s.trim()).filter(Boolean).map((src) => {
		const img = new Image();
		img.src = src;
		img.onload = () => { img.ready = true; };
		return img;
	});
	const STAND_INS = ["pictures soon", "the maps are being decorated", "pictures soon"];
	const slideCount = shots.length || STAND_INS.length;

	// --- Which hand drew it -----------------------------------------------------

	function hash(text) {
		let h = 2166136261;
		for (let i = 0; i < text.length; i++) {
			h ^= text.charCodeAt(i);
			h = Math.imul(h, 16777619);
		}
		return h >>> 0;
	}

	function hand(seed) {
		let s = seed >>> 0;
		return (lo, hi) => {
			s = (s + 0x6d2b79f5) >>> 0;
			let t = Math.imul(s ^ (s >>> 15), 1 | s);
			t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
			return lo + (hi - lo) * (((t ^ (t >>> 14)) >>> 0) / 4294967296);
		};
	}

	// --- Layout ----------------------------------------------------------------------

	let S = 3;          // Screen pixels per canvas pixel.
	let U = 1;          // Canvas pixels per layout unit.
	let W = 0, H = 0;   // The canvas, in its own pixels.
	let WU = 0, HU = 0; // The canvas, in layout units.
	let wide = true;
	let cards = {};     // name -> {x, y, w, h, angle, delay, parts}
	let hits = [];      // {el, name, card, x, y, w, h}: card-local, from its top-left.
	let background = null;
	let blobX = 0;

	function font(size) {
		return size + "px " + FONT;
	}

	// Type is drawn at whole canvas pixels, so this is in layout units at
	// the size it'll really be drawn.
	function textWidth(text, size) {
		const px = pixels(size);
		ctx.font = font(px);
		return ctx.measureText(text).width / U;
	}

	function pixels(size) {
		return Math.max(6, Math.round(size * U));
	}

	function wrap(text, size, width) {
		const out = [];
		let line = "";
		for (const word of text.split(/\s+/)) {
			const next = line ? line + " " + word : word;
			if (line && textWidth(next, size) > width) {
				out.push(line);
				line = word;
			} else {
				line = next;
			}
		}
		if (line) out.push(line);
		return out;
	}

	const deg = (d) => d * Math.PI / 180;

	function layout() {
		const vw = document.documentElement.clientWidth;
		const vh = window.innerHeight;
		const fit = Math.floor(Math.min(vw / DESIGN.w, vh / DESIGN.h));
		wide = fit >= 2 && vw / vh > 1.2;
		const buttons = Array.from(infoEl.querySelectorAll(".hit"));
		let logo, info, pics, size, textSize;
		U = 1;
		if (wide) {
			S = fit;
			W = Math.ceil(vw / S);
			H = Math.ceil(vh / S);
			WU = W;
			HU = H;
			const ox = Math.floor((WU - DESIGN.w) / 2), oy = Math.floor((HU - DESIGN.h) / 2);
			logo = { x: ox + 17, y: oy + 18, w: 164, h: 56, angle: deg(-3) };
			info = { x: ox + 21, y: oy + 94, w: 158, angle: deg(-1.5) };
			pics = { x: ox + 214, y: oy + 98, w: 166, h: 104, angle: deg(-2) };
			blobX = ox + 262;
			size = 17;
			textSize = 10;
		} else {
			S = Math.max(2, Math.round(vw / TALL_LOW));
			W = Math.floor(vw / S);
			WU = W;
			const cw = Math.min(WU - 24, 230);
			const cx = Math.floor((WU - cw) / 2);
			logo = { x: cx, y: 14, w: Math.min(cw - 34, 170), h: 46, angle: deg(-3) };
			pics = { x: cx + 12, y: 78, w: cw - 24, angle: deg(-2) };
			pics.h = Math.round(pics.w * 0.64);
			info = { x: cx, y: pics.y + pics.h + 20, w: cw, angle: deg(-1.5) };
			blobX = WU - 24;
			size = Math.min(17, Math.floor(logo.w / 7));
			textSize = 10;
		}
		logo.size = size;
		logo.delay = 0;
		pics.delay = 0.12;
		info.delay = 0.24;

		// The info card: its lines wrapped, then the buttons, wrapping too.
		const pad = 13;
		const wrapped = [];
		for (const line of lines) wrapped.push(...wrap(line, textSize, info.w - pad * 2));
		info.lines = wrapped;
		info.textSize = textSize;
		let bx = pad, by = pad + wrapped.length * 12 + 7;
		info.buttons = buttons.map((el) => {
			const label = el.getAttribute("data-label") || el.textContent.trim();
			const words = ARROWS[label[0]] && label[1] === " " ? label.slice(2) : label;
			const bw = Math.ceil(textWidth(words, 9)) + 14 + (words !== label ? ARROWS[label[0]][0].length + 3 : 0);
			if (bx + bw > info.w - pad + 2 && bx > pad) {
				bx = pad;
				by += 20;
			}
			const b = { el, name: el.getAttribute("data-button"), label, x: bx, y: by, w: bw, h: 17 };
			bx += bw + 5;
			return b;
		});
		info.h = by + 17 + pad;

		// The picture card: the picture, dots under it, arrows either side.
		pics.image = { x: 9, y: 9, w: pics.w - 18, h: pics.h - 22 };
		pics.prev = { el: picsEl.querySelector('[data-button="prev"]'), name: "prev", x: -17, y: pics.h / 2 - 15, w: 14, h: 30 };
		pics.next = { el: picsEl.querySelector('[data-button="next"]'), name: "next", x: pics.w + 3, y: pics.h / 2 - 15, w: 14, h: 30 };

		if (!wide) {
			HU = Math.max(window.innerHeight / S / U, info.y + info.h + 20);
			H = Math.ceil(HU * U);
		}
		cards = { logo, info, pictures: pics };

		// Lay the real elements over where they're drawn.
		hits = [];
		place(logoEl, logo);
		place(infoEl, info);
		place(picsEl, pics);
		for (const b of info.buttons) hits.push(Object.assign({ card: info }, b));
		hits.push(Object.assign({ card: pics }, pics.prev), Object.assign({ card: pics }, pics.next));
		const k = U * S;
		for (const h of hits) {
			Object.assign(h.el.style, {
				left: h.x * k + "px", top: h.y * k + "px", width: h.w * k + "px", height: h.h * k + "px",
			});
		}

		lettering.clear();
		canvas.width = W;
		canvas.height = H;
		canvas.style.width = W * S + "px";
		canvas.style.height = H * S + "px";
		screen.style.height = wide ? "100vh" : H * S + "px";
		background = dither(W, H);
	}

	function place(el, card) {
		const k = U * S;
		Object.assign(el.style, {
			left: card.x * k + "px", top: card.y * k + "px",
			width: card.w * k + "px", height: card.h * k + "px",
			transform: "rotate(" + card.angle + "rad)",
		});
	}

	// --- The background: black into maroon, in 16-bit colour with an ordered
	// dither, like the game's colours setting. -------------------------------------------

	const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
	const STOPS = [[0, [0, 0, 0]], [0.32, [0, 0, 0]], [0.62, [40, 12, 24]], [1, [118, 46, 72]]];

	function shade(t) {
		for (let i = 1; i < STOPS.length; i++) {
			if (t <= STOPS[i][0]) {
				const [t0, a] = STOPS[i - 1], [t1, b] = STOPS[i];
				const k = (t - t0) / (t1 - t0);
				return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
			}
		}
		return STOPS[STOPS.length - 1][1];
	}

	function dither(w, h) {
		const off = document.createElement("canvas");
		off.width = w;
		off.height = h;
		const c = off.getContext("2d");
		const img = c.createImageData(w, h);
		// 5 bits of red and blue, 6 of green, like RGB565.
		const q = (v, levels, d) => {
			const step = 255 / (levels - 1);
			return Math.max(0, Math.min(255, Math.round(v / step + d) * step));
		};
		for (let y = 0; y < h; y++) {
			const col = shade(h > 1 ? y / (h - 1) : 0);
			for (let x = 0; x < w; x++) {
				const d = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16 - 0.5;
				const i = (y * w + x) * 4;
				img.data[i] = q(col[0], 32, d);
				img.data[i + 1] = q(col[1], 64, d);
				img.data[i + 2] = q(col[2], 32, d);
				img.data[i + 3] = 255;
			}
		}
		c.putImageData(img, 0, 0);
		return off;
	}

	// --- Paper boxes -----------------------------------------------------------------

	function corners(x, y, w, h, rand, amount) {
		return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]].map((p) =>
			[p[0] + rand(-amount, amount), p[1] + rand(-amount, amount)]);
	}

	function path(points) {
		ctx.beginPath();
		ctx.moveTo(points[0][0], points[0][1]);
		for (let i = 1; i < points.length; i++) ctx.lineTo(points[i][0], points[i][1]);
		ctx.closePath();
	}

	// A white card with a black frame set in from its edge, each side a
	// touch off. `fill` fills inside the frame (inverted boxes).
	function paper(x, y, w, h, seed, margin, fill, shadow) {
		const rand = hand(seed);
		const wobble = Math.min(0.4 + margin * 0.18, 1.6);
		const card = corners(x, y, w, h, rand, wobble * 0.6);
		const l = margin * rand(0.6, 1.4), t = margin * rand(0.6, 1.4);
		const r = margin * rand(0.6, 1.4), b = margin * rand(0.6, 1.4);
		const inner = corners(x + l, y + t, w - l - r, h - t - b, rand, wobble);
		if (shadow) {
			path(card.map((p) => [p[0] + shadow, p[1] + shadow]));
			ctx.fillStyle = "rgba(0,0,0,.85)";
			ctx.fill();
		}
		path(card);
		ctx.fillStyle = PAPER;
		ctx.fill();
		if (fill) {
			path(inner);
			ctx.fillStyle = fill;
			ctx.fill();
		}
		path(inner);
		ctx.strokeStyle = INK;
		ctx.lineWidth = margin > 4 ? 1.4 : 1;
		ctx.stroke();
	}

	// Words as one-bit pixel lettering: set small, every pixel either ink or
	// nothing, so a tilted card turns them without smearing thin strokes
	// away. Kept once made.
	const lettering = new Map();

	function letters(str, px, color) {
		const key = str + "|" + px + "|" + color;
		let made = lettering.get(key);
		if (made) return made;
		const c = document.createElement("canvas");
		const g = c.getContext("2d");
		g.font = font(px);
		const base = Math.round(px * 1.05) + 1;
		c.width = Math.ceil(g.measureText(str).width) + 2;
		c.height = base + Math.ceil(px * 0.3) + 1;
		g.font = font(px);
		g.fillStyle = color;
		g.textBaseline = "alphabetic";
		g.fillText(str, 1, base);
		const img = g.getImageData(0, 0, c.width, c.height);
		const rgb = [parseInt(color.slice(1, 3), 16), parseInt(color.slice(3, 5), 16), parseInt(color.slice(5, 7), 16)];
		for (let i = 0; i < img.data.length; i += 4) {
			img.data[i] = rgb[0];
			img.data[i + 1] = rgb[1];
			img.data[i + 2] = rgb[2];
			img.data[i + 3] = img.data[i + 3] > 64 ? 255 : 0;
		}
		g.putImageData(img, 0, 0);
		made = { canvas: c, base };
		lettering.set(key, made);
		return made;
	}

	// `str` with its baseline at (x, y), in layout units.
	function text(str, x, y, size, color) {
		const made = letters(str, pixels(size), color);
		ctx.imageSmoothingEnabled = false;
		ctx.drawImage(made.canvas, x - 1 / U, y - made.base / U, made.canvas.width / U, made.canvas.height / U);
	}

	// A button's words, a leading ↓ or ← drawn as a little pixel arrow (the
	// glyph is lost at this size).
	const ARROWS = {
		"↓": ["..#..", "..#..", "..#..", "#####", ".###.", "..#.."],
		"←": ["..#...", ".##...", "######", ".##...", "..#..."],
	};

	function label(str, x, y, size, color) {
		const icon = ARROWS[str[0]];
		if (icon && str[1] === " ") {
			ctx.fillStyle = color;
			const top = Math.round(y - icon.length - 1);
			icon.forEach((row, j) => {
				for (let i = 0; i < row.length; i++) if (row[i] === "#") ctx.fillRect(Math.round(x) + i, top + j, 1, 1);
			});
			x += icon[0].length + 3;
			str = str.slice(2);
		}
		text(str, x, y, size, color);
	}

	// --- Motion ------------------------------------------------------------------------

	let now = 0;
	const state = { hover: "", focus: "", press: "" };
	const blob = { angle: 0.15, spin: 0 };
	let slide = 0, shown = 0, wipeAt = -1, lastTurn = 0;
	const pops = [];

	function backOut(t) {
		const c = 1.9;
		return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
	}

	// Cards stamp down in turn: big and turned, then home with an overshoot.
	function stamp(card) {
		if (still) return { scale: 1, turn: 0, alpha: 1 };
		const t = Math.max(0, Math.min(1, (now - 0.1 - card.delay) / 0.38));
		return { scale: 1 + 0.8 * (1 - backOut(t)), turn: (1 - t) * deg(9), alpha: Math.min(1, t * 5) };
	}

	function step(dt) {
		// The blob swings like a pendulum, pushed by a slow breeze.
		const breeze = still ? 0 : 0.35 * Math.sin(now * 0.7) + 0.15 * Math.sin(now * 1.9);
		blob.spin += (-16 * blob.angle - 1.1 * blob.spin + breeze) * dt;
		blob.angle += blob.spin * dt;
		// Pictures turn over on their own unless you're at them.
		if (slideCount > 1 && !still && wipeAt < 0 && now - lastTurn > SLIDE_TIME && state.hover !== "prev" && state.hover !== "next") {
			turn(1);
		}
		if (wipeAt >= 0 && now - wipeAt >= WIPE_TIME / 2) shown = slide;
		if (wipeAt >= 0 && now - wipeAt >= WIPE_TIME) wipeAt = -1;
		for (let i = pops.length - 1; i >= 0; i--) if (now - pops[i].born > 2) pops.splice(i, 1);
	}

	function turn(by) {
		slide = (slide + by + slideCount) % slideCount;
		lastTurn = now;
		if (still) {
			shown = slide;
		} else {
			wipeAt = now;
		}
		caption.textContent = "picture " + (slide + 1) + " of " + slideCount + (shots.length ? "" : ": " + STAND_INS[slide]);
	}

	function jolt(amount) {
		if (!still) blob.spin += amount;
	}

	// --- Drawing -------------------------------------------------------------------------

	function draw() {
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.imageSmoothingEnabled = true;
		ctx.drawImage(background, 0, 0);
		// Everything else in layout units.
		ctx.setTransform(U, 0, 0, U, 0, 0);
		drawBlob();
		drawCard(cards.logo, drawLogo);
		drawCard(cards.pictures, drawPictures);
		drawCard(cards.info, drawInfo);
		drawPops();
	}

	function drawCard(card, inside) {
		const a = stamp(card);
		if (a.alpha <= 0) return;
		ctx.save();
		ctx.globalAlpha = a.alpha;
		ctx.translate(card.x + card.w / 2, card.y + card.h / 2);
		ctx.rotate(card.angle + a.turn);
		ctx.scale(a.scale, a.scale);
		ctx.translate(-card.w / 2, -card.h / 2);
		inside(card);
		ctx.restore();
	}

	function drawLogo(card) {
		paper(0, 0, card.w, card.h, 11, 7);
		text(logoText, 17, card.h / 2 + card.size * 0.36, card.size, INK);
	}

	function drawInfo(card) {
		paper(0, 0, card.w, card.h, 23, 6);
		card.lines.forEach((line, i) => text(line, 13, 13 + 9 + i * 12, card.textSize, INK));
		for (const b of card.buttons) {
			const lit = state.hover === b.name || state.focus === b.name;
			const down = state.press === b.name;
			const lift = lit && !down ? -1 : down ? 1 : 0;
			paper(b.x + lift, b.y + lift, b.w, b.h, hash(b.name), 2, lit ? INK : null, lit && !down ? 2 : 0);
			label(b.label, b.x + 7 + lift, b.y + 12 + lift, 9, lit ? PAPER : INK);
		}
	}

	function drawPictures(card) {
		paper(0, 0, card.w, card.h, 37, 6);
		const r = card.image;
		ctx.save();
		ctx.beginPath();
		ctx.rect(r.x, r.y, r.w, r.h);
		ctx.clip();
		if (shots.length && shots[shown].ready) {
			ctx.imageSmoothingEnabled = true;
			// Cover the frame; drawn small, so it comes out in chunky pixels.
			const img = shots[shown];
			const k = Math.max(r.w / img.naturalWidth, r.h / img.naturalHeight);
			const iw = img.naturalWidth * k, ih = img.naturalHeight * k;
			ctx.drawImage(img, r.x + (r.w - iw) / 2, r.y + (r.h - ih) / 2, iw, ih);
		} else {
			standIn(shown, r);
		}
		drawWipe(r);
		ctx.restore();
		ctx.strokeStyle = INK;
		ctx.lineWidth = 1;
		ctx.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
		// A dot for each picture, the one showing filled.
		const dots = slideCount;
		const x0 = card.w / 2 - (dots * 6 - 3) / 2;
		for (let i = 0; i < dots; i++) {
			ctx.fillStyle = i === slide ? INK : "#c9c9cf";
			ctx.fillRect(Math.round(x0 + i * 6), Math.round(card.h - 10), 3, 3);
		}
		arrow(card.prev, -1);
		arrow(card.next, 1);
	}

	// A chunky hand-drawn chevron, nudged out when you point at it.
	function arrow(a, dir) {
		const lit = state.hover === a.name || state.focus === a.name;
		const push = (lit ? 2 : 0) + (state.press === a.name ? 2 : 0);
		const rand = hand(hash(a.name));
		const cx = a.x + a.w / 2 + dir * push, cy = a.y + a.h / 2;
		const pts = [[cx - dir * 3, cy - 10], [cx + dir * 4, cy + rand(-1, 1)], [cx - dir * 3 + rand(-1, 1), cy + 10]];
		ctx.beginPath();
		ctx.moveTo(pts[0][0], pts[0][1]);
		ctx.quadraticCurveTo(cx + dir * 2, cy - 4, pts[1][0], pts[1][1]);
		ctx.quadraticCurveTo(cx + dir * 1, cy + 5, pts[2][0], pts[2][1]);
		ctx.lineCap = "round";
		ctx.lineJoin = "round";
		ctx.strokeStyle = lit ? PINK : PAPER;
		ctx.lineWidth = lit ? 2.6 : 2;
		ctx.stroke();
	}

	// The game's scene wipe in small: black boxes pop in on a diagonal, the
	// picture changes behind them, and they clear the same way.
	function drawWipe(r) {
		if (wipeAt < 0) return;
		const p = (now - wipeAt) / WIPE_TIME;
		const cols = 8, rows = 5;
		const cw = r.w / cols, ch = r.h / rows;
		ctx.fillStyle = INK;
		for (let i = 0; i < cols; i++) {
			for (let j = 0; j < rows; j++) {
				const d = (i + j) / (cols + rows - 2);
				const k = p < 0.5 ? Math.max(0, Math.min(1, (p * 2 - d * 0.6) / 0.4)) : Math.max(0, Math.min(1, 1 - ((p - 0.5) * 2 - d * 0.6) / 0.4));
				if (k <= 0) continue;
				const sw = cw * k, sh = ch * k;
				ctx.fillRect(Math.floor(r.x + i * cw + (cw - sw) / 2), Math.floor(r.y + j * ch + (ch - sh) / 2), Math.ceil(sw), Math.ceil(sh));
			}
		}
	}

	// Stand-ins till the maps are decorated: small scenes in the game's
	// colours, and a box saying so.
	function standIn(i, r) {
		if (i === 1) {
			// A dark stage with a spotlight and a blob under it, like the menu.
			ctx.fillStyle = "#120d18";
			ctx.fillRect(r.x, r.y, r.w, r.h);
			const g = ctx.createRadialGradient(r.x + r.w * 0.5, r.y + r.h * 0.95, 1, r.x + r.w * 0.5, r.y + r.h * 0.95, r.w * 0.35);
			g.addColorStop(0, "rgba(255,240,250,.45)");
			g.addColorStop(1, "rgba(255,240,250,0)");
			ctx.fillStyle = g;
			ctx.beginPath();
			ctx.moveTo(r.x + r.w * 0.45, r.y);
			ctx.lineTo(r.x + r.w * 0.55, r.y);
			ctx.lineTo(r.x + r.w * 0.72, r.y + r.h);
			ctx.lineTo(r.x + r.w * 0.28, r.y + r.h);
			ctx.fill();
			figure(r.x + r.w * 0.5, r.y + r.h * 0.92, r.h * 0.62, Math.sin(now * 3) * 0.06);
		} else {
			// The sky every map has, the sun low in it, greybox blocks.
			const g = ctx.createLinearGradient(0, r.y, 0, r.y + r.h);
			g.addColorStop(0, "#3d296b");
			g.addColorStop(0.5, "#8f61b8");
			g.addColorStop(1, "#ff8f7a");
			ctx.fillStyle = g;
			ctx.fillRect(r.x, r.y, r.w, r.h);
			ctx.fillStyle = "#ffebb3";
			ctx.beginPath();
			ctx.arc(r.x + r.w * (i === 0 ? 0.74 : 0.26), r.y + r.h * 0.62, r.h * 0.1, 0, Math.PI * 2);
			ctx.fill();
			const rand = hand(101 + i);
			let x = r.x - 4;
			while (x < r.x + r.w) {
				const bw = rand(8, 22), bh = rand(r.h * 0.12, r.h * (i === 0 ? 0.55 : 0.3));
				const top = i === 0 ? r.y + r.h - bh : r.y + r.h * rand(0.35, 0.75);
				ctx.fillStyle = rand(0, 1) > 0.5 ? "#5b4a78" : "#6d5a8e";
				ctx.fillRect(Math.round(x), Math.round(top), Math.round(bw), Math.round(i === 0 ? bh : rand(3, 6)));
				ctx.fillStyle = "rgba(255,255,255,.25)";
				ctx.fillRect(Math.round(x), Math.round(top), Math.round(bw), 1);
				x += bw + (i === 0 ? rand(0, 4) : rand(6, 18));
			}
			if (i === 2) figure(r.x + r.w * 0.5, r.y + r.h * 0.56, r.h * 0.4, Math.sin(now * 2) * 0.1);
			ctx.fillStyle = "rgba(179,112,143,.35)";
			ctx.fillRect(r.x, r.y + r.h * 0.7, r.w, r.h * 0.3);
		}
		const label = STAND_INS[i];
		const size = 9;
		const lw = Math.ceil(textWidth(label, size)) + 16;
		const lx = Math.round(r.x + (r.w - lw) / 2), ly = Math.round(r.y + 5);
		ctx.globalAlpha *= 0.9;
		paper(lx, ly, lw, 14, hash(label), 2);
		ctx.globalAlpha /= 0.9;
		text(label, lx + 8, ly + 10.5, size, INK);
	}

	// The game's blank glossy figure, standing: a slab of a body, stubby
	// legs, a ball of a head, and a pink heart in its chest.
	function figure(x, feet, height, lean) {
		ctx.save();
		ctx.translate(x, feet);
		ctx.rotate(lean);
		const u = height / 10;
		ctx.fillStyle = "#f2eef7";
		ctx.fillRect(-2.2 * u, -3.2 * u, 1.8 * u, 3.2 * u);
		ctx.fillRect(0.4 * u, -3.2 * u, 1.8 * u, 3.2 * u);
		roundRect(-2.4 * u, -7.2 * u, 4.8 * u, 4.4 * u, 1.2 * u);
		ctx.fill();
		ctx.beginPath();
		ctx.arc(0, -8.4 * u, 1.7 * u, 0, Math.PI * 2);
		ctx.fill();
		ctx.fillStyle = PINK;
		ctx.fillRect(Math.round(0.4 * u), Math.round(-6 * u), Math.max(1, Math.round(u * 0.8)), Math.max(1, Math.round(u * 0.8)));
		ctx.restore();
	}

	function roundRect(x, y, w, h, r) {
		ctx.beginPath();
		ctx.moveTo(x + r, y);
		ctx.arcTo(x + w, y, x + w, y + h, r);
		ctx.arcTo(x + w, y + h, x, y + h, r);
		ctx.arcTo(x, y + h, x, y, r);
		ctx.arcTo(x, y, x + w, y, r);
		ctx.closePath();
	}

	// The blob hanging upside down from the top of the screen: chest, neck
	// and a ball of a head, its heart's beads going round.
	function drawBlob() {
		const drop = still ? 0 : Math.min(0, -60 * (1 - backOut(Math.max(0, Math.min(1, (now - 0.45) / 0.6)))));
		ctx.save();
		ctx.translate(blobX, 4 + drop);
		ctx.rotate(blob.angle);
		const body = ctx.createLinearGradient(-18, -10, 16, 44);
		body.addColorStop(0, "#fbf8ff");
		body.addColorStop(0.6, "#d8cfe4");
		body.addColorStop(1, "#8f84a3");
		ctx.fillStyle = body;
		roundRect(-19, -40, 38, 50, 10);
		ctx.fill();
		ctx.fillRect(-6, 6, 12, 10);
		ctx.beginPath();
		ctx.arc(0, 27, 13, 0, Math.PI * 2);
		ctx.fill();
		// A glint on the head.
		ctx.fillStyle = "rgba(255,255,255,.9)";
		ctx.fillRect(-7, 21, 3, 2);
		// The heart: a dark pocket, pink at the rim, beads going round.
		const hx = 5, hy = -4;
		ctx.fillStyle = "#b02551";
		ctx.beginPath();
		ctx.arc(hx, hy, 4.5, 0, Math.PI * 2);
		ctx.fill();
		ctx.fillStyle = "#1a0710";
		ctx.beginPath();
		ctx.arc(hx, hy, 3.3, 0, Math.PI * 2);
		ctx.fill();
		for (let i = 0; i < 6; i++) {
			const a = -now * Math.PI * 2 * 0.9 + i * Math.PI / 3;
			ctx.fillStyle = i === 0 ? "#fff4f7" : PINK;
			ctx.fillRect(Math.round(hx + Math.cos(a) * 2.2 - 0.5), Math.round(hy + Math.sin(a) * 2.2 - 0.5), 1, 1);
		}
		ctx.restore();
	}

	// "soon :)" in letter tiles over a button that has nowhere to go yet:
	// they slam down, hold, then drop away.
	function drawPops() {
		for (const pop of pops) {
			const age = now - pop.born;
			let x = pop.x - (pop.text.length * 10) / 2;
			const rand = hand(hash(pop.text) + Math.floor(pop.born * 10));
			for (let i = 0; i < pop.text.length; i++, x += 10) {
				const ch = pop.text[i];
				if (ch === " ") continue;
				const t = Math.max(0, Math.min(1, (age - i * 0.04) / 0.14));
				if (t <= 0) continue;
				const fall = Math.max(0, age - 1.1 - i * 0.03);
				const scale = 1 + 1.2 * (1 - t);
				const turn = rand(-0.12, 0.12) + (1 - t) * rand(-0.6, 0.6) + fall * rand(-6, 6);
				ctx.save();
				ctx.translate(x + 4.5, pop.y + 6 + fall * fall * 220);
				ctx.rotate(turn);
				ctx.scale(scale, scale);
				ctx.globalAlpha = Math.min(1, t * 3) * Math.max(0, 1 - fall * 1.5);
				paper(-5, -7, 10, 13, hash(ch) + i, 1.5, INK);
				text(ch, -3, 3, 9, PAPER);
				ctx.restore();
			}
		}
	}

	// --- The real buttons ----------------------------------------------------------------

	function bind() {
		for (const el of document.querySelectorAll(".hit")) {
			const name = el.getAttribute("data-button");
			el.addEventListener("pointerenter", () => {
				state.hover = name;
				if (["pc", "mac", "server"].includes(name)) jolt(1.6);
			});
			el.addEventListener("pointerleave", () => {
				if (state.hover === name) state.hover = "";
				if (state.press === name) state.press = "";
			});
			el.addEventListener("pointerdown", () => { state.press = name; });
			el.addEventListener("pointerup", () => { state.press = ""; });
			el.addEventListener("focus", () => { state.focus = el.matches(":focus-visible") ? name : ""; });
			el.addEventListener("blur", () => { if (state.focus === name) state.focus = ""; });
			el.addEventListener("click", (e) => {
				if (name === "prev" || name === "next") {
					turn(name === "prev" ? -1 : 1);
					return;
				}
				if (!el.getAttribute("href")) {
					e.preventDefault();
					soon(name);
				}
			});
		}
		window.addEventListener("keydown", (e) => {
			if (e.target.closest && e.target.closest("a, button, input, textarea")) return;
			if (e.key === "ArrowLeft") turn(-1);
			if (e.key === "ArrowRight") turn(1);
		});
		window.addEventListener("resize", () => layout());
	}

	function soon(name) {
		const b = cards.info.buttons.find((x) => x.name === name);
		if (!b) return;
		// Over the card, above the button (out of the card's turn into the
		// screen's), where it covers no words.
		const c = cards.info;
		const lx = b.x + b.w / 2 - c.w / 2, ly = -c.h / 2;
		const cos = Math.cos(c.angle), sin = Math.sin(c.angle);
		pops.push({
			text: "soon :)", born: now,
			x: c.x + c.w / 2 + lx * cos - ly * sin,
			y: c.y + c.h / 2 + lx * sin + ly * cos - 17,
		});
		jolt(3);
		status.textContent = "";
		status.textContent = "downloads soon";
	}

	// --- Go ------------------------------------------------------------------------------

	let then = performance.now();
	function frame(t) {
		const dt = Math.min((t - then) / 1000, 1 / 20);
		then = t;
		now += dt;
		step(dt);
		draw();
		requestAnimationFrame(frame);
	}

	function go() {
		layout();
		bind();
		requestAnimationFrame((t) => {
			then = t;
			requestAnimationFrame(frame);
		});
		// Lay out again once the font's in, since the words' widths change.
		if (window.FontFace && document.fonts) {
			const face = new FontFace("Liberation Sans", 'local("Liberation Sans"), url("assets/LiberationSans-Regular.ttf")');
			face.load().then((f) => {
				document.fonts.add(f);
				layout();
			}).catch(() => {});
		}
	}

	go();
})();
