# New Conquer Offline

A focused offline conversion of the original Conquer Online Mobile client and its supplied game resources.

## Current conversion target

- Preserve the original client APKs and resource files unchanged.
- Extract the original compressed resource archives and stage assets that Godot can load natively (textures, audio, and standard 3D formats).
- Keep proprietary Conquer formats in their original form until a compatible reader/converter is available; never rename or misrepresent them as converted assets.
- Replace online/server-dependent startup and gameplay services with local equivalents only where required for a working offline client.
- Defer new gameplay features, world redesign, economy changes, and visual redesign until the original content is running locally.

The first offline milestone is to launch the original content locally without connecting to the original game servers. A successful Godot import or save-data test alone does not count as completion.


## Environment texture credits

Street and plaza PBR maps are CC0 assets from Poly Haven: [Pavement 05](https://polyhaven.com/a/pavement_05) and [Stone Pathway](https://polyhaven.com/a/stone_pathway). **Powered by Poly Haven.**
