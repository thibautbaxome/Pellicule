#!/usr/bin/env python3
"""Génère l'icône de l'application.

Aucune bibliothèque d'image n'étant disponible dans l'environnement de
développement, l'icône est dessinée pixel par pixel puis encodée en PNG à la
main (zlib + CRC32, ce que la spécification demande et rien de plus).

Le motif est une amorce de pellicule 135 vue de face : la bande, ses
perforations et le photogramme. iOS n'accepte aucune transparence dans une
icône d'application, d'où l'encodage en RVB sans canal alpha.

Relancer après toute modification du motif :

    python3 Tools/make-icon.py
"""

import struct
import zlib
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets" / "AppIcon.appiconset"

BACKGROUND = (0x10, 0x0F, 0x12)
FILM = (0xE8, 0xA3, 0x3D)
FRAME = (0x1A, 0x19, 0x1E)


def rounded_rect(x, y, w, h, radius, px, py):
    """Vrai si le point (px, py) tombe dans le rectangle à coins arrondis."""
    if not (x <= px < x + w and y <= py < y + h):
        return False
    # Seuls les quatre coins demandent un test de distance.
    cx = min(max(px, x + radius), x + w - radius)
    cy = min(max(py, y + radius), y + h - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius**2


def render(size):
    """Rend l'icône à la taille demandée, en lignes de triplets RVB."""
    u = size / 100.0  # unité relative, pour raisonner en pourcentage

    band_x, band_w = 14 * u, 72 * u
    band_y, band_h = 24 * u, 52 * u
    band_r = 5 * u

    # Bandes de perforations, en haut et en bas de la pellicule.
    perf_h = 9 * u
    perf_w = 6 * u
    perf_gap = 4 * u
    perf_top = band_y + 4 * u
    perf_bottom = band_y + band_h - 4 * u - perf_h

    # Photogramme central.
    frame_x = band_x + 8 * u
    frame_w = band_w - 16 * u
    frame_y = band_y + 17 * u
    frame_h = band_h - 34 * u

    perforations = []
    x = band_x + 5 * u
    while x + perf_w <= band_x + band_w - 4 * u:
        perforations.append(x)
        x += perf_w + perf_gap

    rows = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            color = BACKGROUND

            if rounded_rect(band_x, band_y, band_w, band_h, band_r, px, py):
                color = FILM

                for perf_x in perforations:
                    if rounded_rect(perf_x, perf_top, perf_w, perf_h, 1.5 * u, px, py) or (
                        rounded_rect(perf_x, perf_bottom, perf_w, perf_h, 1.5 * u, px, py)
                    ):
                        color = BACKGROUND

                if rounded_rect(frame_x, frame_y, frame_w, frame_h, 2 * u, px, py):
                    color = FRAME

            row += bytes(color)
        rows.append(bytes(row))
    return rows


def write_png(path, size):
    rows = render(size)
    # Chaque ligne est préfixée de son octet de filtre (0 = aucun).
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")

    path.write_bytes(png)
    print(f"{path.name} — {size}×{size}, {len(png)} octets")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # Depuis iOS 17, une seule image de 1024 points suffit : le système
    # engendre lui-même toutes les tailles dérivées.
    write_png(OUTPUT_DIR / "icon-1024.png", 1024)


if __name__ == "__main__":
    main()
