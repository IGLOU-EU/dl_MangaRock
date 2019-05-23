# dl_MangaRock

Script for downloading Manga from MangaRock.com to .cbz format.

Clone or download, make the script and binary executable, ant lets go !
Minimal execution arg '--url' and '--out'

ex:
```
dlmr.sh --out ./out --url 'https://mangarock.com/manga/mrs-serie-259071'
```

---
The binari is a go compilled program for Linux_x86_64 : https://github.com/bake/mri
For converting mri (MangaRockImage) into other format (like png)

---
This script do not manage volume, but only chapters. So a lot of .cbz is generated (one by chapters).
Because MangaRock manage only chapters, and do not give any volume indication by json API.

Maybe add later a option for downloading all at once inside a .cbz (but ... that can be very big ...)