#!/usr/bin/env python3
"""Bag icons for the cozy-tools + fishing pass — pickaxe, axe, fishing rod, and a
couple of fish. 16x16, stdlib PNG (zlib + struct), same grounded palette and style
as gen_farm.py. Run: python3 tools/gen_tools.py
"""

import os
import struct
import zlib

OUTLINE = (26, 20, 16, 255)


class Canvas:
	def __init__(self, w, h):
		self.w = w
		self.h = h
		self.buf = bytearray(w * h * 4)

	def put(self, x, y, c):
		if x < 0 or y < 0 or x >= self.w or y >= self.h:
			return
		if len(c) == 3:
			c = (c[0], c[1], c[2], 255)
		if c[3] == 0:
			return
		i = (y * self.w + x) * 4
		self.buf[i], self.buf[i + 1], self.buf[i + 2], self.buf[i + 3] = c

	def rect(self, x0, y0, x1, y1, c):
		if x1 < x0:
			x0, x1 = x1, x0
		if y1 < y0:
			y0, y1 = y1, y0
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				self.put(x, y, c)

	def line(self, x0, y0, x1, y1, c):
		dx = abs(x1 - x0)
		dy = abs(y1 - y0)
		sx = 1 if x0 < x1 else -1
		sy = 1 if y0 < y1 else -1
		err = dx - dy
		while True:
			self.put(x0, y0, c)
			if x0 == x1 and y0 == y1:
				break
			e2 = 2 * err
			if e2 > -dy:
				err -= dy
				x0 += sx
			if e2 < dx:
				err += dx
				y0 += sy

	def outline(self, color=OUTLINE):
		src = bytes(self.buf)

		def op(x, y):
			if x < 0 or y < 0 or x >= self.w or y >= self.h:
				return False
			return src[(y * self.w + x) * 4 + 3] != 0

		for y in range(self.h):
			for x in range(self.w):
				if op(x, y):
					continue
				if op(x - 1, y) or op(x + 1, y) or op(x, y - 1) or op(x, y + 1):
					self.put(x, y, color)

	def save(self, name):
		raw = bytearray()
		for y in range(self.h):
			raw.append(0)
			raw += self.buf[y * self.w * 4:(y + 1) * self.w * 4]
		comp = zlib.compress(bytes(raw), 9)

		def chunk(tag, data):
			return (struct.pack(">I", len(data)) + tag + data
					+ struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

		png = b"\x89PNG\r\n\x1a\n"
		png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
		png += chunk(b"IDAT", comp)
		png += chunk(b"IEND", b"")
		path = os.path.join(os.path.dirname(__file__), "..", "assets",
							"placeholder", "items", name)
		os.makedirs(os.path.dirname(path), exist_ok=True)
		with open(path, "wb") as f:
			f.write(png)
		print("generated items/" + name)


WOOD = ((150, 104, 60), (118, 80, 44))
IRON = ((150, 156, 168), (104, 110, 122), (70, 74, 86))
LINE = (210, 206, 196)
BOB = (180, 70, 60)
FISH = ((120, 150, 176), (84, 116, 146), (56, 84, 112))
FISH2 = ((150, 158, 130), (112, 122, 96), (78, 88, 66))


def gen_pickaxe():
	c = Canvas(16, 16)
	c.line(11, 3, 5, 13, WOOD[1])  # handle
	c.line(12, 3, 6, 13, WOOD[0])
	# double-pointed steel head arcing over the top
	c.line(7, 3, 11, 2, IRON[1])
	c.line(12, 3, 14, 6, IRON[1])
	c.line(7, 3, 5, 5, IRON[1])
	c.put(11, 2, IRON[0])
	c.put(5, 5, IRON[0])
	c.put(14, 6, IRON[2])
	c.outline()
	c.save("pickaxe.png")


def gen_axe():
	c = Canvas(16, 16)
	c.line(10, 3, 6, 13, WOOD[1])  # haft
	c.line(11, 3, 7, 13, WOOD[0])
	# blade
	c.rect(8, 2, 13, 6, IRON[1])
	c.rect(8, 2, 13, 2, IRON[0])
	c.rect(13, 2, 13, 6, IRON[2])
	c.put(7, 4, IRON[2])
	c.outline()
	c.save("axe.png")


def gen_fishing_rod():
	c = Canvas(16, 16)
	c.line(3, 13, 13, 2, WOOD[1])  # the pole
	c.line(4, 13, 14, 2, WOOD[0])
	c.put(3, 13, WOOD[1])
	# the line dropping from the tip, ending in a red bob
	c.line(13, 2, 11, 11, LINE)
	c.put(11, 12, BOB)
	c.put(11, 11, BOB)
	c.save("fishing_rod.png")


def _fish(pal, name):
	c = Canvas(16, 16)
	c.rect(4, 7, 10, 10, pal[1])  # body
	c.rect(5, 6, 9, 6, pal[0])
	c.rect(5, 11, 9, 11, pal[2])
	c.put(3, 8, pal[1]); c.put(3, 9, pal[1])  # snout
	# tail
	c.put(11, 7, pal[1]); c.put(12, 6, pal[2])
	c.put(11, 10, pal[1]); c.put(12, 11, pal[2])
	c.put(11, 8, pal[2]); c.put(11, 9, pal[2])
	c.put(4, 8, (240, 240, 240))  # eye
	c.put(4, 8, (30, 30, 30))
	c.outline()
	c.save(name)


def gen_fish():
	_fish(FISH, "river_fish.png")
	_fish(FISH2, "lake_bass.png")


if __name__ == "__main__":
	gen_pickaxe()
	gen_axe()
	gen_fishing_rod()
	gen_fish()
	print("gen_tools: done.")
