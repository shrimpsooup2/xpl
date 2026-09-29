// xtrapartial's website: the game's UI brought to the page.
//
// - Boxes are drawn by hand like the game's (src/ui/paper_box.gd): a white
//   card with a thin black frame set in from its edge, each box's margins,
//   corners and frame lines a touch off, differently for every box and the
//   same every time.
// - Letter tiles slam down one after another, like the game's pop-ups.
// - Cards spring in as they come into view.
// - The heart: six glowing beads going round in a pocket in a chest, each
//   on its own spring (src/player/heart.gd). Poke it.
// - Glossy props float in the sky.
//
// No libraries. Everything still reads without it (plain CSS frames).

(function () {
	"use strict";

	var root = document.documentElement;
	var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	var SVG = "http://www.w3.org/2000/svg";

	// --- Which hand drew it: a seeded random, so a box is crooked the same
	// way every time. ---------------------------------------------------------

	function hash(text) {
		var h = 2166136261;
		for (var i = 0; i < text.length; i++) {
			h ^= text.charCodeAt(i);
			h = Math.imul(h, 16777619);
		}
		return h >>> 0;
	}

	function hand(seed) {
		var s = seed >>> 0;
		return function (lo, hi) {
			s = (s + 0x6d2b79f5) >>> 0;
			var t = Math.imul(s ^ (s >>> 15), 1 | s);
			t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
			var r = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
			return lo + (hi - lo) * r;
		};
	}

	// --- Paper boxes -----------------------------------------------------------

	var seeds = new WeakMap();
	var drawn = 0;

	// The rect's corners (clockwise from top left), each nudged a little.
	function corners(x, y, w, h, rand, amount) {
		var out = [];
		[[x, y], [x + w, y], [x + w, y + h], [x, y + h]].forEach(function (p) {
			out.push([p[0] + rand(-amount, amount), p[1] + rand(-amount, amount)]);
		});
		return out;
	}

	function points(list) {
		return list.map(function (p) { return p[0].toFixed(2) + "," + p[1].toFixed(2); }).join(" ");
	}

	function shape(tag, cls, pts) {
		var el = document.createElementNS(SVG, tag);
		el.setAttribute("class", cls);
		el.setAttribute("points", points(pts));
		return el;
	}

	function draw(box) {
		var w = box.offsetWidth, h = box.offsetHeight;
		if (!w || !h) return;
		var rand = hand(seeds.get(box));
		var margin = parseFloat(getComputedStyle(box).getPropertyValue("--m")) || 5;
		var wobble = Math.min(0.5 + margin * 0.3, 3);
		var card = corners(0, 0, w, h, rand, wobble * 0.6);
		// The frame sits in from each edge by a different amount.
		var l = margin * rand(0.6, 1.4), t = margin * rand(0.6, 1.4);
		var r = margin * rand(0.6, 1.4), b = margin * rand(0.6, 1.4);
		var inner = corners(l, t, w - l - r, h - t - b, rand, wobble);
		var svg = box.querySelector(":scope > svg.paper");
		if (!svg) {
			svg = document.createElementNS(SVG, "svg");
			svg.setAttribute("class", "paper");
			svg.setAttribute("aria-hidden", "true");
			box.insertBefore(svg, box.firstChild);
		}
		svg.setAttribute("width", w);
		svg.setAttribute("height", h);
		svg.setAttribute("viewBox", "0 0 " + w + " " + h);
		while (svg.firstChild) svg.removeChild(svg.firstChild);
		if (box.classList.contains("btn")) {
			svg.appendChild(shape("polygon", "under", card.map(function (p) { return [p[0] + 4, p[1] + 4]; })));
		}
		svg.appendChild(shape("polygon", "card", card));
		svg.appendChild(shape("polygon", "fill", inner));
		svg.appendChild(shape("polygon", "line", inner));
	}

	var resized = "ResizeObserver" in window ? new ResizeObserver(function (entries) {
		entries.forEach(function (e) { draw(e.target); });
	}) : null;

	function paper(box) {
		if (seeds.has(box)) return;
		seeds.set(box, hash((box.textContent || "").slice(0, 60)) + 7919 * drawn++);
		draw(box);
		if (resized) resized.observe(box);
	}

	function paperAll(scope) {
		(scope || document).querySelectorAll(".box").forEach(paper);
	}

	// --- Letter tiles ------------------------------------------------------------

	function tiles(el) {
		var text = el.textContent.trim();
		var style = el.getAttribute("data-tiles") || "inv";
		var rand = hand(hash(text));
		el.setAttribute("aria-label", text);
		el.textContent = "";
		var i = 0;
		// A word never breaks across lines, except after a hyphen.
		text.split(/\s+/).join(" ").replace(/-/g, "- ").split(" ").forEach(function (word) {
			var group = document.createElement("span");
			group.className = "word" + (/-$/.test(word) ? " joined" : "");
			group.setAttribute("aria-hidden", "true");
			el.appendChild(group);
			Array.from(word).forEach(function (ch) {
				var span = document.createElement("span");
				span.className = "box tile" + (style === "plain" ? "" : " " + style);
				span.textContent = ch;
				span.style.setProperty("--i", i++);
				span.style.setProperty("--r0", rand(-28, 28).toFixed(1) + "deg");
				span.style.setProperty("--r1", rand(-4, 4).toFixed(1) + "deg");
				// Where it tumbles off to when it shatters.
				span.style.setProperty("--dx", rand(-90, 90).toFixed(0) + "px");
				span.style.setProperty("--dy", rand(-40, 90).toFixed(0) + "px");
				span.style.setProperty("--r2", rand(-200, 200).toFixed(0) + "deg");
				group.appendChild(span);
			});
		});
	}

	// --- Coming into view --------------------------------------------------------

	var seen = "IntersectionObserver" in window ? new IntersectionObserver(function (entries) {
		entries.forEach(function (e) {
			if (!e.isIntersecting) return;
			e.target.classList.add("in");
			seen.unobserve(e.target);
		});
	}, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }) : null;

	function watch(el) {
		if (seen) seen.observe(el);
		else el.classList.add("in");
	}

	// Siblings arrive one after another.
	function stagger() {
		document.querySelectorAll(".reveal").forEach(function (el) {
			var kin = Array.prototype.filter.call(el.parentElement.children, function (c) {
				return c.classList.contains("reveal");
			});
			el.style.setProperty("--d", (Math.min(kin.indexOf(el), 5) * 0.06).toFixed(2) + "s");
		});
	}

	// --- The HUD's ammo column -----------------------------------------------------

	function ammo(el) {
		var rounds = parseInt(el.getAttribute("data-rounds"), 10);
		if (!rounds) return;
		// 9 px × √rounds on the game's 270 px canvas, here at about 1.7×.
		var height = Math.round(15.5 * Math.sqrt(rounds));
		el.style.setProperty("--h", height + "px");
		var small = rounds <= 12;
		el.classList.add(small ? "cells" : "notched");
		el.style.setProperty("--cell", (small ? height / rounds : height * 10 / rounds).toFixed(2) + "px");
		var count = document.createElement("span");
		count.className = "count";
		count.textContent = rounds;
		el.appendChild(count);
		el.setAttribute("role", "img");
		el.setAttribute("aria-label", rounds + " rounds");
	}

	// --- Props in the sky ----------------------------------------------------------

	var PROPS = [
		// left %, top %, size px, colour, seconds a turn, tilt, opacity
		[6, 18, 64, "#dbd1b3", 46, 24, 0.9],
		[84, 9, 42, "#8ce6ff", 38, -18, 0.75],
		[73, 52, 90, "#e0806e", 60, 14, 0.55],
		[14, 68, 38, "#b8a6e0", 34, 30, 0.7],
		[46, 84, 54, "#f2a7c3", 52, -24, 0.45],
		[92, 76, 30, "#a8e0c8", 30, 20, 0.6],
	];

	function props() {
		var sky = document.querySelector(".sky");
		if (!sky || still) return;
		PROPS.forEach(function (p) {
			var prop = document.createElement("div");
			prop.className = "prop";
			prop.style.cssText = "left:" + p[0] + "%;top:" + p[1] + "%;--s:" + p[2] + "px;--c:" + p[3] +
				";--t:" + p[4] + "s;--x:" + p[5] + "deg;--o:" + p[6] + ";animation-delay:-" + (p[4] * p[0] / 100).toFixed(1) + "s";
			for (var i = 0; i < 6; i++) prop.appendChild(document.createElement("i"));
			sky.appendChild(prop);
		});
	}

	// --- The heart ----------------------------------------------------------------
	//
	// The game's numbers (src/player/heart.gd), with lengths in ring radii so
	// they work at any size: springs of the same stiffness and damping, the
	// same kick and slack, the same spin.

	var DOTS = 6;
	var DOT_SIZE = 0.42;      // Bead radius / ring radius (0.011 / 0.026).
	var TAIL_SIZE = 0.55;     // The last bead's size against the lead's.
	var STIFFNESS = 700;
	var DAMPING = 14;
	var SLACK = 0.35;         // How far a bead can lag its place (0.009 / 0.026).
	var KICK = 34.6;          // A hit's kick (0.9 m/s / 0.026 m).
	var SPIN_REST = 0.9;      // Turns a second.
	var SPIN_FAST = 2.4;
	var HITCH_TIME = 0.25;
	var DYING_BELOW = 0.35;
	var HIT = 0.25;           // Health a poke takes.
	var SPILLED_FOR = 3.2;    // Seconds before it loads again.

	function mix(a, b, t) { return a + (b - a) * t; }

	function rgb(a, b, t) {
		return "rgb(" + Math.round(mix(a[0], b[0], t)) + "," + Math.round(mix(a[1], b[1], t)) + "," + Math.round(mix(a[2], b[2], t)) + ")";
	}

	var PINK = [255, 61, 115];
	var HOT = [255, 244, 247];
	var GREY = [120, 112, 124];
	var DARK = [40, 30, 40];

	function Heart(stage) {
		this.stage = stage;
		this.canvas = stage.querySelector("canvas");
		this.ctx = this.canvas.getContext("2d");
		this.caption = stage.querySelector(".caption");
		this.dots = [];
		for (var i = 0; i < DOTS; i++) this.dots.push({ x: 0, y: 0, vx: 0, vy: 0, free: false, dark: 0 });
		this.angle = 0;
		this.health = 1;
		this.hitch = 0;
		this.grey = 0;
		this.flash = 0;
		this.spilled = -1;       // Seconds since it spilled (< 0: it hasn't).
		this.loose = 0;          // Seconds the beads swing free of the slack (coming back).
		this.stopped = stage.getAttribute("data-heart") === "timed-out";
		this.rate = SPIN_REST;
		this.speed = 0;          // How fast the page is moving: "your speed".
		this.visible = true;
		this.placed = false;
		this.resize();
		this.bind();
	}

	Heart.prototype.resize = function () {
		var r = this.canvas.getBoundingClientRect();
		var dpr = Math.min(window.devicePixelRatio || 1, 2);
		this.w = r.width;
		this.h = r.height;
		this.canvas.width = Math.round(r.width * dpr);
		this.canvas.height = Math.round(r.height * dpr);
		this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		// The chest, and the pocket in it a little off its middle.
		this.pocket = Math.min(this.w, this.h) * 0.15;
		this.ring = this.pocket * 0.55;
		this.cx = this.w * 0.53;
		this.cy = this.h * 0.47;
		if (!this.placed) {
			this.placed = true;
			for (var i = 0; i < DOTS; i++) {
				var p = this.place(i);
				this.dots[i].x = p[0];
				this.dots[i].y = p[1];
			}
		}
	};

	// Where bead i belongs: round the ring, or settled in a heap at the
	// bottom of the pocket once it's stopped.
	Heart.prototype.place = function (i) {
		if (this.stopped) {
			var row = i < 3 ? 0 : 1;
			var col = (i % 3) - 1;
			var bead = this.ring * DOT_SIZE;
			return [this.cx + col * bead * 2.05 + row * bead, this.cy + this.pocket * 0.62 - bead - row * bead * 1.75];
		}
		var sag = this.health < DYING_BELOW ? this.ring * 0.12 : 0;
		var a = this.angle - i * (Math.PI * 2 / DOTS);
		return [this.cx + Math.cos(a) * this.ring, this.cy + Math.sin(a) * this.ring + sag];
	};

	Heart.prototype.bind = function () {
		var self = this;
		var poke = function (e) {
			if (e) e.preventDefault();
			self.poke();
		};
		this.canvas.addEventListener("pointerdown", poke);
		this.canvas.addEventListener("keydown", function (e) {
			if (e.key === "Enter" || e.key === " ") poke(e);
		});
		var last = window.scrollY;
		window.addEventListener("scroll", function () {
			var dy = window.scrollY - last;
			last = window.scrollY;
			if (still) return;
			// The beads lag behind as the page moves.
			self.speed = Math.min(self.speed + Math.abs(dy) * 0.02, 1);
			for (var i = 0; i < DOTS; i++) if (!self.dots[i].free) self.dots[i].vy += dy * self.ring * 0.05;
		}, { passive: true });
		window.addEventListener("resize", function () { self.resize(); });
		if ("IntersectionObserver" in window) {
			new IntersectionObserver(function (entries) {
				self.visible = entries[0].isIntersecting;
				if (self.visible) self.start();
			}).observe(this.stage);
		}
	};

	Heart.prototype.poke = function () {
		if (this.spilled >= 0) return;
		if (this.stopped) {
			// Timed out: a poke loads it again.
			this.stopped = false;
			this.health = 1;
			this.grey = 1;
			this.loose = 0.6;
			return;
		}
		this.health -= HIT;
		if (this.health <= 0.001) {
			this.spill();
			return;
		}
		// Hit: the beads rattle, the spin hitches and the pocket greys, like lag.
		this.hitch = HITCH_TIME;
		this.grey = 1;
		for (var i = 0; i < DOTS; i++) {
			var a = Math.random() * Math.PI * 2;
			var kick = KICK * this.ring * (still ? 0.2 : 1);
			this.dots[i].vx += Math.cos(a) * kick;
			this.dots[i].vy += Math.sin(a) * kick;
		}
	};

	// A heartshot: the beads flash white and spill out of the chest.
	Heart.prototype.spill = function () {
		this.spilled = 0;
		this.flash = 1;
		for (var i = 0; i < DOTS; i++) {
			var d = this.dots[i];
			d.free = true;
			d.dark = 0;
			var a = -Math.PI / 2 + (Math.random() - 0.5) * 2.2;
			var speed = this.ring * (9 + Math.random() * 9);
			d.vx = Math.cos(a) * speed;
			d.vy = Math.sin(a) * speed;
		}
		popup(this.stage, "heartshot");
	};

	Heart.prototype.revive = function () {
		this.spilled = -1;
		this.health = 1;
		this.loose = 0.6;
		for (var i = 0; i < DOTS; i++) {
			var d = this.dots[i];
			d.free = false;
			d.dark = 0;
			var p = this.place(i);
			d.x = this.cx;
			d.y = this.cy;
			d.vx = (p[0] - this.cx) * 10;
			d.vy = (p[1] - this.cy) * 10;
		}
	};

	Heart.prototype.step = function (dt) {
		// Spin: faster the faster the page moves, held while hit, stuttering
		// near death, stopped once it's timed out.
		this.speed = Math.max(this.speed - dt * 1.5, 0);
		var want = still ? 0.12 : mix(SPIN_REST, SPIN_FAST, this.speed);
		this.rate += (want - this.rate) * Math.min(dt * 4, 1);
		var turning = !this.stopped && this.hitch <= 0 && this.spilled < 0;
		if (turning && this.health < DYING_BELOW && Math.sin(this.angle * 3.1) > 0.82) turning = false;
		if (turning) this.angle += this.rate * Math.PI * 2 * dt;
		this.hitch = Math.max(this.hitch - dt, 0);
		this.grey = Math.max(this.grey - dt / HITCH_TIME, 0);
		this.flash = Math.max(this.flash - dt * 2.5, 0);
		this.loose = Math.max(this.loose - dt, 0);

		var floor = this.h - this.ring * DOT_SIZE - 6;
		for (var i = 0; i < DOTS; i++) {
			var d = this.dots[i];
			if (d.free) {
				// Spilled: little bodies bouncing about the floor, going dark.
				d.vy += this.h * 2.6 * dt;
				d.x += d.vx * dt;
				d.y += d.vy * dt;
				if (d.y > floor) {
					d.y = floor;
					d.vy *= -0.45;
					d.vx *= 0.8;
				}
				if (d.x < 6 || d.x > this.w - 6) {
					d.x = Math.min(Math.max(d.x, 6), this.w - 6);
					d.vx *= -0.6;
				}
				d.dark = Math.min(d.dark + dt / 2, 1);
				continue;
			}
			var p = this.place(i);
			var ax = STIFFNESS * (p[0] - d.x) - DAMPING * d.vx;
			var ay = STIFFNESS * (p[1] - d.y) - DAMPING * d.vy;
			d.vx += ax * dt;
			d.vy += ay * dt;
			d.x += d.vx * dt;
			d.y += d.vy * dt;
			// Never further from its place than the slack (unless it's on its
			// way back in).
			var ox = d.x - p[0], oy = d.y - p[1];
			var off = Math.sqrt(ox * ox + oy * oy);
			var slack = SLACK * this.ring;
			if (off > slack && this.loose <= 0) {
				d.x = p[0] + ox / off * slack;
				d.y = p[1] + oy / off * slack;
			}
		}
		if (this.spilled >= 0) {
			this.spilled += dt;
			if (this.spilled > SPILLED_FOR) this.revive();
		}
	};

	Heart.prototype.draw = function () {
		var c = this.ctx, w = this.w, h = this.h;
		c.clearRect(0, 0, w, h);
		var cx = this.cx, cy = this.cy, R = this.pocket;

		// The chest: a glossy blank slab with arms going down and out, lit
		// from above left with a pink rim.
		var top = cy - R * 2.4, left = cx - R * 3.2, right = cx + R * 2.9;
		var body = c.createLinearGradient(left, top, right, h);
		body.addColorStop(0, "#fbf8ff");
		body.addColorStop(0.55, "#d7cfe3");
		body.addColorStop(1, "#8f84a3");
		c.save();
		c.lineCap = "round";
		c.strokeStyle = "#c9c0d8";
		c.lineWidth = R * 1.45;
		c.beginPath();
		c.moveTo(left + R * 0.7, top + R * 0.9);
		c.lineTo(left - R * 1.4, h + R);
		c.moveTo(right - R * 0.7, top + R * 0.9);
		c.lineTo(right + R * 1.4, h + R);
		c.stroke();
		c.beginPath();
		roundRect(c, left, top, right - left, h - top + R * 2, R * 1.6);
		// A short neck up into a big ball of a head, cut off by the frame.
		var mid = (left + right) / 2;
		roundRect(c, mid - R * 0.75, top - R * 1.2, R * 1.5, R * 1.6, R * 0.5);
		c.moveTo(mid + R * 2.3, top - R * 2.35);
		c.arc(mid, top - R * 2.35, R * 2.3, 0, Math.PI * 2);
		c.fillStyle = body;
		c.shadowColor = "rgba(255, 150, 200, .55)";
		c.shadowBlur = R * 0.6;
		c.fill("nonzero");
		c.shadowBlur = 0;
		var shine = c.createRadialGradient(left + R * 1.2, top + R * 0.8, 0, left + R * 1.2, top + R * 0.8, R * 2.4);
		shine.addColorStop(0, "rgba(255,255,255,.9)");
		shine.addColorStop(1, "rgba(255,255,255,0)");
		c.fillStyle = shine;
		c.fill();
		c.restore();

		// The pocket: lined pink at the rim, near black at the back.
		var grey = this.stopped ? 1 : this.grey;
		var lining = c.createRadialGradient(cx, cy + R * 0.12, R * 0.1, cx, cy, R);
		lining.addColorStop(0, "#07030a");
		lining.addColorStop(0.55, rgb([42, 10, 26], [26, 24, 28], grey));
		lining.addColorStop(0.86, rgb([176, 37, 81], [96, 90, 100], grey));
		lining.addColorStop(1, rgb([255, 122, 160], [190, 184, 196], grey));
		c.beginPath();
		c.arc(cx, cy, R, 0, Math.PI * 2);
		c.fillStyle = lining;
		c.fill();
		// The lip's shadow falling into it.
		var lip = c.createLinearGradient(cx, cy - R, cx, cy + R);
		lip.addColorStop(0, "rgba(0,0,0,.45)");
		lip.addColorStop(0.35, "rgba(0,0,0,0)");
		c.fillStyle = lip;
		c.fill();

		// The beads: the lead one biggest and white-hot, the tail smaller and
		// pinker.
		var bead = this.ring * DOT_SIZE;
		var dying = !this.stopped && this.spilled < 0 && this.health < DYING_BELOW;
		for (var i = DOTS - 1; i >= 0; i--) {
			var d = this.dots[i];
			var t = i / (DOTS - 1);
			var size = bead * mix(1, TAIL_SIZE, t);
			var pink = Math.min(t * 2, 1);
			var tint;
			if (d.free) tint = rgb(this.flash > 0 ? HOT : PINK, DARK, d.dark);
			else if (this.stopped) tint = rgb(GREY, DARK, t * 0.5);
			else if (grey > 0) tint = rgb(pink < 0.5 ? HOT : PINK, GREY, grey * 0.8);
			else tint = rgb(HOT, PINK, pink);
			var alpha = dying && Math.random() < 0.12 ? 0.35 : 1;
			c.globalAlpha = alpha;
			c.beginPath();
			c.arc(d.x, d.y, size, 0, Math.PI * 2);
			c.fillStyle = tint;
			c.shadowColor = this.stopped || (d.free && d.dark > 0.7) ? "transparent" : "rgba(255, 61, 115, .9)";
			c.shadowBlur = size * 2.2;
			c.fill();
			c.shadowBlur = 0;
			// A glint.
			c.beginPath();
			c.arc(d.x - size * 0.35, d.y - size * 0.35, size * 0.28, 0, Math.PI * 2);
			c.fillStyle = "rgba(255,255,255," + (this.stopped ? 0.25 : 0.7) + ")";
			c.fill();
			c.globalAlpha = 1;
		}

		if (this.flash > 0) {
			c.fillStyle = "rgba(255, 220, 235," + (this.flash * 0.35).toFixed(3) + ")";
			c.fillRect(0, 0, w, h);
		}
	};

	Heart.prototype.start = function () {
		if (this.running) return;
		this.running = true;
		var self = this, then = performance.now();
		var frame = function (now) {
			var dt = Math.min((now - then) / 1000, 1 / 20);
			then = now;
			// Small steps keep the stiff springs steady.
			var steps = Math.max(1, Math.ceil(dt / (1 / 240)));
			for (var i = 0; i < steps; i++) self.step(dt / steps);
			self.draw();
			if (self.visible || self.spilled >= 0) requestAnimationFrame(frame);
			else self.running = false;
		};
		requestAnimationFrame(frame);
	};

	function roundRect(c, x, y, w, h, r) {
		c.moveTo(x + r, y);
		c.arcTo(x + w, y, x + w, y + h, r);
		c.arcTo(x + w, y + h, x, y + h, r);
		c.arcTo(x, y + h, x, y, r);
		c.arcTo(x, y, x + w, y, r);
		c.closePath();
	}

	// A pop-up over a stage: letter tiles slam down, hold, and go.
	function popup(stage, text) {
		var old = stage.querySelector(".pop");
		if (old) old.remove();
		var pop = document.createElement("div");
		pop.className = "pop tiles";
		pop.setAttribute("data-tiles", "heart");
		pop.setAttribute("role", "status");
		pop.textContent = text;
		stage.appendChild(pop);
		tiles(pop);
		paperAll(pop);
		requestAnimationFrame(function () { pop.classList.add("in"); });
		setTimeout(function () { pop.classList.add("out"); }, 1300);
		setTimeout(function () { pop.remove(); }, 1700);
	}

	// --- Go --------------------------------------------------------------------------

	function start() {
		props();
		document.querySelectorAll("[data-tiles]").forEach(tiles);
		document.querySelectorAll(".ammo[data-rounds]").forEach(ammo);
		paperAll();
		root.classList.add("drawn");
		stagger();
		document.querySelectorAll(".reveal, .tiles").forEach(watch);
		document.querySelectorAll("[data-heart]").forEach(function (stage) {
			if (!stage.querySelector("canvas") || !stage.querySelector("canvas").getContext) return;
			var heart = new Heart(stage);
			heart.draw();
			heart.start();
		});
		// Fonts can change sizes after the first drawing.
		if (document.fonts && document.fonts.ready) {
			document.fonts.ready.then(function () {
				document.querySelectorAll(".box").forEach(draw);
			});
		}
	}

	if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
	else start();
})();
