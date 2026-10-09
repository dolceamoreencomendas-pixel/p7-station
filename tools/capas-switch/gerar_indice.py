#!/usr/bin/env python3
"""Gera o índice de capas de Nintendo Switch do P7 Station.

Entrada: US.en.json do projeto titledb (github.com/blawar/titledb), com os jogos da eShop.
Saída: um TSV pequeno (nome normalizado, ID do jogo, código da imagem do ícone na CDN da eShop).
O app não guarda imagens: só monta o endereço https://img-eshop.cdn.nintendo.net/i/<código>.jpg.

Uso: python3 gerar_indice.py US.en.json ../../src/themes/hub-vidro/switch-capas.tsv
"""
import json
import re
import sys
import unicodedata


def normalize(title):
    """Igual a P7Bridge::normalizeTitle no C++ (mantenha as duas iguais)."""
    t = unicodedata.normalize("NFD", title)
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = t.lower().replace("™", "").replace("®", "").replace("©", "")
    t = re.sub(r"[\(\[][^\)\]]*[\)\]]", "", t)
    t = t.replace("&", " and ")
    t = re.sub(r"\bthe\b", "", t)
    return re.sub(r"[^a-z0-9]+", "", t)


def main(src, dst):
    data = json.load(open(src, encoding="utf-8"))
    rows = {}
    for v in data.values():
        tid = (v.get("id") or "").upper()
        name = v.get("name") or ""
        icon = v.get("iconUrl") or ""
        if len(tid) != 16 or not tid.endswith("000") or not name or not icon:
            continue
        m = re.search(r"/i/([0-9a-f]{64})\.jpg$", icon)
        if not m:
            continue
        key = normalize(name)
        if not key:
            continue
        rows.setdefault(tid, (key, m.group(1)))
    with open(dst, "w", encoding="utf-8") as out:
        out.write("# capas de Switch: nome normalizado, ID, ícone (img-eshop.cdn.nintendo.net/i/<ícone>.jpg). Fonte: titledb\n")
        for tid, (key, h) in sorted(rows.items()):
            out.write(f"{key}\t{tid}\t{h}\n")
    print(len(rows), "jogos")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
