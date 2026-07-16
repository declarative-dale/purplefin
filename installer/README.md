# Purplefin Anaconda installer

`Containerfile` creates the installer environment used by the bootc installer
ISO. It includes the ordinary Anaconda flow plus Purplefin's role selector.

The selector intentionally does not compose packages on the target. It detects
hardware, limits the visible presets to the catalog, verifies the selected
GitHub Actions cosign signature, resolves the tag to a digest, and returns an
Anaconda-compatible `registry:` bootc source reference.

The Anaconda UI integration calls:

```python
from purplefin.source_selection import resolve_source
source = resolve_source(selected_preset)
```

and assigns `source` to the bootc payload source before installation starts.
The implementation must use the Anaconda release's bootc source D-Bus API;
the mapping and verification policy deliberately remain outside that unstable
UI API. The ISO build uses `base-generic-x86_64` as image-builder's required
embedded fallback payload. The selector replaces it with the verified network
source selected by the user.
