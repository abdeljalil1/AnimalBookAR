# Vendored libraries

- `mindar/`: MindAR 1.2.5 (MIT), image tracking. From npm `mind-ar@1.2.5`, `dist/`.
- `three/`: three.js 0.160.0 (MIT). `three.module.js` is `build/three.module.min.js`;
  `addons/` holds only the files MindAR and the app import.

Bare `three` imports were rewritten to relative paths so the page works without
import maps (needed for iOS 15 to 16.3 and older Android WebViews):

```bash
sed -i '' -e 's#from "three/addons/renderers/CSS3DRenderer.js"#from "../three/addons/renderers/CSS3DRenderer.js"#' -e 's#from "three"#from "../three/three.module.js"#' mindar/mindar-image-three.prod.js
sed -i '' -e "s#from 'three'#from '../../three.module.js'#" three/addons/*/*.js
```
