// xtrapartial's website: one screen, drawn small and blown up in hard
// pixels like the game's 3D (360 lines, point-filtered), with the game's
// boxes: white cards with a crooked black frame set in from the edge
// (src/ui/paper_box.gd), the logo card being the game's logo. The words
// and buttons come from the page's HTML, which stays over the canvas
// unseen so links, the keyboard and screen readers work.
//
// - The background dithers from black to maroon in 16-bit colour, like
//   the game's optional colours mode.
// - The player hangs upside down from the top by its feet, swinging
//   (assets/figure.png, rendered from the game by
//   tools/gen_site_figure.gd). Hover a download and it jolts.
// - The picture card flips through screenshots (data-shots) with the
//   game's box wipe, or low-res stand-ins until there are some.
// - A download without an address yet says "soon :)". Pointing at one (or
//   tabbing to it) shows its tooltip, from its title in the HTML: an
//   inverted box over the button, the build and the version on top.
// - The version (the page's data-version, stamped in from project.godot by
//   tools/build_site.sh) is a tag stuck under the logo.

(function () {
	"use strict";

	const still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	const screen = document.getElementById("screen");
	const canvas = document.getElementById("pixels");
	const ctx = canvas.getContext("2d");
	const status = document.getElementById("status");
	const FONT = 'Arial, "Liberation Sans", Helvetica, sans-serif';
	const INK = "#0d0d0f";
	const PAPER = "#ffffff";
	const GREY = "#8c8c94";
	const PINK = "#ff3d73";
	// The layout wide screens get, in layout units, scaled to fill the
	// screen; narrower ones stack, TALL units across. The canvas is about
	// DESIGN.w pixels across (TALL_LOW on a phone), and each of its pixels
	// is a whole number of screen pixels.
	const DESIGN = { w: 640, h: 360 };
	const TALL = 270;
	const TALL_LOW = 200;
	const SLIDE_TIME = 5.0;
	const WIPE_TIME = 0.5;

	// --- The page's words ----------------------------------------------------

	const logoEl = document.querySelector('[data-card="logo"]');
	const infoEl = document.querySelector('[data-card="info"]');
	const picsEl = document.querySelector('[data-card="pictures"]');
	const logoText = logoEl.querySelector("h1").textContent.trim();
	const logoImage = picture("assets/logo.png", () => layout());
	const figureImage = picture("assets/figure.png");
	const lines = Array.from(infoEl.querySelectorAll("li"), (li) => li.textContent.trim());
	const caption = picsEl.querySelector(".caption");
	const version = screen.getAttribute("data-version") || "";
	const stage = screen.getAttribute("data-stage") || ""; // "beta" while it is one.
	// The downloads' tooltips: drawn here, so not the browser's as well;
	// screen readers get them as the links' descriptions.
	for (const el of infoEl.querySelectorAll(".hit[title]")) {
		el.dataset.tip = el.title;
		el.setAttribute("aria-description", el.title);
		el.removeAttribute("title");
	}
	const shots = (picsEl.getAttribute("data-shots") || "").split(",").map((s) => s.trim()).filter(Boolean).map((src) => picture(src));
	const STAND_INS = ["pictures soon", "the maps are being decorated", "pictures soon"];
	const slideCount = shots.length || STAND_INS.length;

	function picture(src, loaded) {
		const img = new Image();
		img.onload = () => {
			img.ready = true;
			if (loaded) loaded();
		};
		img.src = src;
		return img;
	}

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
	let cards = {};     // name -> {x, y, w, h, angle, delay, ...}
	let hits = [];      // {el, name, card, x, y, w, h}: card-local, from its top-left.
	let background = null;
	let hanger = { x: 0, y: 0, h: 0 }; // The figure: where its feet hang from, and how tall.

	function font(size) {
		return size + "px " + FONT;
	}

	// In layout units.
	function textWidth(text, size) {
		ctx.font = font(size);
		return ctx.measureText(text).width;
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

	// Wrapped, with no word left on a line of its own.
	function balanced(text, size, width) {
		const lines = wrap(text, size, width);
		const n = lines.length;
		if (n > 1 && !/\s/.test(lines[n - 1])) {
			const words = lines[n - 2].split(" ");
			if (words.length > 2) {
				lines[n - 1] = words.pop() + " " + lines[n - 1];
				lines[n - 2] = words.join(" ");
			}
		}
		return lines;
	}

	const deg = (d) => d * Math.PI / 180;

	function logoAspect() {
		return logoImage.ready ? logoImage.naturalWidth / logoImage.naturalHeight : 3.5;
	}

	function layout() {
		const vw = document.documentElement.clientWidth;
		const vh = window.innerHeight;
		wide = vw / vh > 1.2 && vw >= 640;
		const buttons = Array.from(infoEl.querySelectorAll(".hit"));
		let logo, info, pics, textSize;
		if (wide) {
			S = Math.max(2, Math.round(Math.min(vw / DESIGN.w, vh / DESIGN.h)));
			W = Math.ceil(vw / S);
			H = Math.ceil(vh / S);
			U = Math.min(W / DESIGN.w, H / DESIGN.h);
			WU = W / U;
			HU = H / U;
			const ox = (WU - DESIGN.w) / 2, oy = (HU - DESIGN.h) / 2;
			logo = { x: ox + 30, y: oy + 28, w: 282, angle: deg(-3) };
			logo.h = logo.w / logoAspect();
			info = { x: ox + 34, y: oy + 136, w: 272, angle: deg(-1.5) };
			pics = { x: ox + 342, y: oy + 142, w: 262, h: 172, angle: deg(-2) };
			hanger = { x: ox + 474, y: -64, h: 170 };
			textSize = 16;
		} else {
			S = Math.max(2, Math.round(vw / TALL_LOW));
			W = Math.ceil(vw / S);
			U = W / TALL;
			WU = TALL;
			const cw = WU - 28;
			const cx = 14;
			logo = { x: cx + 2, y: 16, w: cw - 62, angle: deg(-3) };
			logo.h = logo.w / logoAspect();
			pics = { x: cx + 18, y: logo.y + logo.h + 34, w: cw - 36, angle: deg(-2) };
			pics.h = Math.round(pics.w * 0.64);
			info = { x: cx, y: pics.y + pics.h + 26, w: cw, angle: deg(-1.5) };
			hanger = { x: WU - 34, y: -54, h: 118 };
			textSize = 15;
		}
		logo.delay = 0;
		pics.delay = 0.12;
		info.delay = 0.24;

		// The info card: its lines wrapped, then the buttons, wrapping too.
		const pad = 18, lead = Math.round(textSize * 1.3);
		const wrapped = [];
		for (const line of lines) wrapped.push(...balanced(line, textSize, info.w - pad * 2));
		info.lines = wrapped;
		info.textSize = textSize;
		info.lead = lead;
		info.pad = pad;
		let bx = pad, by = pad + wrapped.length * lead + 10;
		info.buttons = buttons.map((el) => {
			const label = el.getAttribute("data-label") || el.textContent.trim();
			const bw = Math.ceil(textWidth(label, BUTTON_TEXT)) + 24;
			if (bx + bw > info.w - pad + 3 && bx > pad) {
				bx = pad;
				by += BUTTON_H + 7;
			}
			const b = { el, name: el.getAttribute("data-button"), label, tip: el.dataset.tip || "", x: bx, y: by, w: bw, h: BUTTON_H };
			bx += bw + 8;
			return b;
		});
		info.h = by + BUTTON_H + pad;

		// The picture card: the picture, dots under it, arrows either side.
		pics.image = { x: 12, y: 12, w: pics.w - 24, h: pics.h - 32 };
		pics.prev = { el: picsEl.querySelector('[data-button="prev"]'), name: "prev", x: -28, y: pics.h / 2 - 24, w: 22, h: 48 };
		pics.next = { el: picsEl.querySelector('[data-button="next"]'), name: "next", x: pics.w + 6, y: pics.h / 2 - 24, w: 22, h: 48 };

		if (!wide) {
			HU = Math.max(window.innerHeight / S / U, info.y + info.h + 26);
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

		canvas.width = W;
		canvas.height = H;
		canvas.style.width = W * S + "px";
		canvas.style.height = H * S + "px";
		screen.style.height = wide ? "100vh" : H * S + "px";
		background = dither(W, H);
	}

	const BUTTON_TEXT = 14;
	const BUTTON_H = 26;

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
		ctx.lineWidth = margin > 4 ? 2 : 1.2;
		ctx.stroke();
	}

	// `str` in Arial with its baseline at (x, y), in layout units.
	function text(str, x, y, size, color) {
		ctx.font = font(size);
		ctx.fillStyle = color;
		ctx.textBaseline = "alphabetic";
		ctx.fillText(str, x, y);
	}

	// --- Motion ------------------------------------------------------------------------

	let now = 0;
	const state = { hover: "", focus: "", press: "" };
	const blob = { angle: 0.15, spin: 0 }; // The hanging player's swing.
	let slide = 0, shown = 0, wipeAt = -1, lastTurn = 0;
	let tipName = "", tipAt = 0; // The tooltip showing, and since when.
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
		drawHanger();
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

	// The game's logo; the words in a box till it's in. The version on a
	// tag stuck under its corner.
	function drawLogo(card) {
		if (logoImage.ready) {
			ctx.imageSmoothingEnabled = true;
			ctx.drawImage(logoImage, 0, 0, card.w, card.h);
		} else {
			paper(0, 0, card.w, card.h, 11, 9);
			text(logoText, card.h * 0.35, card.h * 0.64, card.h * 0.38, INK);
		}
		if (version) {
			const label = "v" + version + (stage ? " " + stage : ""), size = 12;
			const w = Math.ceil(textWidth(label, size)) + 18, h = 20;
			ctx.save();
			ctx.translate(card.w - w / 2 - 14, card.h + 2);
			ctx.rotate(deg(5));
			paper(-w / 2, -h / 2, w, h, hash(label), 2.5);
			text(label, -w / 2 + 9, 4.5, size, INK);
			ctx.restore();
		}
	}

	function drawInfo(card) {
		paper(0, 0, card.w, card.h, 23, 9);
		card.lines.forEach((line, i) => text(line, card.pad, card.pad + card.textSize + i * card.lead, card.textSize, INK));
		for (const b of card.buttons) {
			const lit = state.hover === b.name || state.focus === b.name;
			const down = state.press === b.name;
			const lift = lit && !down ? -1.5 : down ? 1.5 : 0;
			paper(b.x + lift, b.y + lift, b.w, b.h, hash(b.name), 3, lit ? INK : null, lit && !down ? 3 : 0);
			text(b.label, b.x + 12 + lift, b.y + b.h / 2 + BUTTON_TEXT * 0.36 + lift, BUTTON_TEXT, lit ? PAPER : INK);
		}
		const pointed = card.buttons.find((b) => b.tip && (state.hover === b.name || state.focus === b.name));
		if ((pointed ? pointed.name : "") !== tipName) {
			tipName = pointed ? pointed.name : "";
			tipAt = now;
		}
		if (pointed) drawTip(card, pointed);
	}

	// A button's tooltip: an inverted box over it, pointing down at it, the
	// build and the version on top, then what it is. It pops up from the
	// button.
	function drawTip(card, b) {
		const size = 12, lead = 15, padX = 10, padY = 8;
		const lines = [b.name + (version ? " · v" + version + (stage ? " " + stage : "") : ""), ...wrap(b.tip, size, 210)];
		const w = Math.ceil(Math.max(...lines.map((l) => textWidth(l, size)))) + padX * 2;
		const h = lines.length * lead + padY * 2 - 2;
		const cx = b.x + b.w / 2;
		const x = Math.max(-8, Math.min(card.w - w + 8, cx - w / 2));
		const y = b.y - h - 10;
		const t = still ? 1 : Math.min(1, (now - tipAt) / 0.16);
		const k = 0.7 + 0.3 * backOut(t);
		ctx.save();
		ctx.globalAlpha *= Math.min(1, t * 4);
		ctx.translate(cx, b.y - 4);
		ctx.scale(k, k);
		ctx.translate(-cx, -(b.y - 4));
		paper(x, y, w, h, hash(b.name) + 7, 3, INK, 2);
		// The point, down at the button.
		ctx.beginPath();
		ctx.moveTo(cx - 7, y + h - 1);
		ctx.lineTo(cx + 7, y + h - 1);
		ctx.lineTo(cx, y + h + 8);
		ctx.closePath();
		ctx.fillStyle = PAPER;
		ctx.fill();
		ctx.beginPath();
		ctx.moveTo(cx - 4, y + h - 4);
		ctx.lineTo(cx + 4, y + h - 4);
		ctx.lineTo(cx, y + h + 3);
		ctx.closePath();
		ctx.fillStyle = INK;
		ctx.fill();
		lines.forEach((l, i) => text(l, x + padX, y + padY + size - 1 + i * lead, size, i === 0 ? PINK : PAPER));
		ctx.restore();
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
		ctx.lineWidth = 2;
		ctx.strokeRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2);
		// A dot for each picture, the one showing filled.
		const dots = slideCount;
		const x0 = card.w / 2 - (dots * 10 - 5) / 2;
		for (let i = 0; i < dots; i++) {
			ctx.fillStyle = i === slide ? INK : "#c9c9cf";
			ctx.fillRect(x0 + i * 10, card.h - 15, 5, 5);
		}
		arrow(card.prev, -1);
		arrow(card.next, 1);
	}

	// A chunky hand-drawn chevron, nudged out when you point at it.
	function arrow(a, dir) {
		const lit = state.hover === a.name || state.focus === a.name;
		const push = (lit ? 3 : 0) + (state.press === a.name ? 3 : 0);
		const rand = hand(hash(a.name));
		const k = a.h / 30;
		const cx = a.x + a.w / 2 + dir * push, cy = a.y + a.h / 2;
		const pts = [[cx - dir * 3 * k, cy - 10 * k], [cx + dir * 4 * k, cy + rand(-1, 1) * k], [cx - dir * 3 * k + rand(-1, 1) * k, cy + 10 * k]];
		ctx.beginPath();
		ctx.moveTo(pts[0][0], pts[0][1]);
		ctx.quadraticCurveTo(cx + dir * 2 * k, cy - 4 * k, pts[1][0], pts[1][1]);
		ctx.quadraticCurveTo(cx + dir * 1 * k, cy + 5 * k, pts[2][0], pts[2][1]);
		ctx.lineCap = "round";
		ctx.lineJoin = "round";
		ctx.strokeStyle = lit ? PINK : PAPER;
		ctx.lineWidth = lit ? 3.6 : 3;
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
			if (i === 2) figure(r.x + r.w * 0.5, r.y + r.h * 0.66, r.h * 0.36, Math.sin(now * 2) * 0.1);
			ctx.fillStyle = "rgba(179,112,143,.35)";
			ctx.fillRect(r.x, r.y + r.h * 0.7, r.w, r.h * 0.3);
		}
		const label = STAND_INS[i];
		const size = 13;
		const lw = Math.ceil(textWidth(label, size)) + 22;
		const lx = r.x + (r.w - lw) / 2, ly = r.y + 8;
		ctx.globalAlpha *= 0.9;
		paper(lx, ly, lw, 22, hash(label), 3);
		ctx.globalAlpha /= 0.9;
		text(label, lx + 11, ly + 15.5, size, INK);
	}

	// The player (assets/figure.png: hanging by its feet, arms dangling),
	// `height` tall from its soles at (x, y), turned `angle`; the right way
	// up it's cheering.
	function player(x, y, height, angle) {
		if (!figureImage.ready) return;
		const w = height * figureImage.naturalWidth / figureImage.naturalHeight;
		ctx.save();
		ctx.translate(x, y);
		ctx.rotate(angle);
		ctx.imageSmoothingEnabled = true;
		ctx.drawImage(figureImage, -w / 2, 0, w, height);
		ctx.restore();
	}

	// Stood up in a stand-in picture, bobbing.
	function figure(x, feet, height, lean) {
		player(x, feet, height, Math.PI + lean);
	}

	// Hanging upside down from the top of the screen, legs out of sight,
	// swinging. It drops in once the cards are down.
	function drawHanger() {
		const drop = still ? 0 : Math.min(0, -hanger.h * (1 - backOut(Math.max(0, Math.min(1, (now - 0.45) / 0.6)))));
		player(hanger.x, hanger.y + drop, hanger.h, blob.angle);
	}

	// "soon :)" in letter tiles over a button that has nowhere to go yet:
	// they slam down, hold, then drop away.
	function drawPops() {
		const step = 17;
		for (const pop of pops) {
			const age = now - pop.born;
			let x = pop.x - (pop.text.length * step) / 2;
			const rand = hand(hash(pop.text) + Math.floor(pop.born * 10));
			for (let i = 0; i < pop.text.length; i++, x += step) {
				const ch = pop.text[i];
				if (ch === " ") continue;
				const t = Math.max(0, Math.min(1, (age - i * 0.04) / 0.14));
				if (t <= 0) continue;
				const fall = Math.max(0, age - 1.1 - i * 0.03);
				const scale = 1 + 1.2 * (1 - t);
				const turn = rand(-0.12, 0.12) + (1 - t) * rand(-0.6, 0.6) + fall * rand(-6, 6);
				ctx.save();
				ctx.translate(x + 8, pop.y + 10 + fall * fall * 380);
				ctx.rotate(turn);
				ctx.scale(scale, scale);
				ctx.globalAlpha = Math.min(1, t * 3) * Math.max(0, 1 - fall * 1.5);
				paper(-8, -11, 16, 21, hash(ch) + i, 2, INK);
				ctx.textAlign = "center";
				text(ch, 0, 5, 15, PAPER);
				ctx.textAlign = "left";
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
			y: c.y + c.h / 2 + lx * sin + ly * cos - 28,
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
		// Without Arial, its look-alike from assets/, laid out again once in
		// since the words' widths change.
		if (!hasArial() && window.FontFace && document.fonts) {
			const face = new FontFace("Liberation Sans", 'local("Liberation Sans"), url("assets/LiberationSans-Regular.ttf")');
			face.load().then((f) => {
				document.fonts.add(f);
				layout();
			}).catch(() => {});
		}
	}

	function hasArial() {
		const probe = "mmmmmmmmmmlli";
		ctx.font = "40px monospace";
		const fallback = ctx.measureText(probe).width;
		ctx.font = "40px Arial, monospace";
		return ctx.measureText(probe).width !== fallback;
	}

	go();
})();
