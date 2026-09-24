# Lifetime tier artwork

Generated September 23, 2026 with the built-in image generation tool, using the existing app illustrations as visual references. Existing assets were left unchanged. No CLI/API fallback or image post-processing was used.

## Assets and validation

- `Braver Search/Shared (App)/Assets.xcassets/TipHighFive.imageset/tip-high-five.png`: **High five!**, $4.99. Two of the existing white cub characters with raised paws touching. Visually inspected: coherent two-arm poses, familiar red-orange outline, blue background, circular white inset, radial lines, no text.
- `Braver Search/Shared (App)/Assets.xcassets/TipLove.imageset/tip-love.png`: **Now that's love!**, $49.99. Existing adult lion character hugging a large heart. Visually inspected: matching mane/face/palette, coherent hug, no text.

Both files are native generated **1254 × 1254 PNG** output, copied unchanged into the asset catalog. The prompt requested 1024 square; the tool chose 1254 square. SwiftUI scales the universal image asset to the card size. Original generated files are retained outside the repository by the tool.

## High five prompt

Reference images in order: `TipCheers.imageset/tip-cheers.png`, `TipThanks.imageset/tip-thanks.png`, both under the same asset catalog.

```text
Use case: illustration-story. Asset type: production square purchase-tier illustration for the Braver Search app, 1024 by 1024 pixels.
Input image 1 is the primary style and character reference: the existing Cheers illustration with two white lion cubs drinking coffee. Input image 2 is an additional character reference of the same white cub giving a thumbs-up.
Create a sibling illustration in this EXACT existing icon family, changing ONLY the action and pose to HIGH FIVE. Two of the SAME cheerful white lion cubs face each other and raise their inner forepaws, paws touching at the top center in one unmistakable joyful high five. Their other arms rest naturally down; anatomically coherent, two arms per cub, no extra limbs. Show their smiling faces and white torsos. Use the exact red-orange thick clean contours, white fur, tiny blush cheeks, pale blue shaded accents, spiky forehead tufts, circular ears and red-orange eyes/noses as references. One tiny gold sparkle beside the meeting paws.
Keep the same square cyan-at-top to rich royal-blue-at-bottom gradient background; the same huge centered white circular inset; the same short red-orange radial lines around the inner circle, size, margins and overall composition as image 1. Large expressive characters fill the circle. Clean polished flat graphic shading like reference, not 3D, no painterly textures, no realism, no redesign. No mugs, no text, no lettering, no prices, no logos, no watermark. Preserve complete square edge-to-edge blue background. This must look like it was drawn by the identical illustrator in the same set.
```

## Love prompt

Reference images in order: `TipLifesaver.imageset/tip-lifesaver.png`, `TipCheers.imageset/tip-cheers.png`, both under the same asset catalog.

```text
Use case: illustration-story. Asset type: production square purchase-tier illustration for the Braver Search app, target 1024 by 1024 pixels.
Input image 1 is the primary style and character reference: the existing Lifesaver illustration with an orange-maned white adult lion carrying a white cub. Input image 2 is the same app's Cheers illustration to match its badge/background format.
Create a sibling illustration in this EXACT existing icon family for the idea NOW THAT'S LOVE. Feature the SAME smiling white adult lion with a full orange mane, small rounded ears, tufts, red-orange outlines, happy closed crescent eyes, and pink blush, holding an oversized warm coral-red heart against its chest in a tender hug. The lion's two white front paws curve around the left and right sides of the large heart; make coherent arms, two arms total, no extra limbs. Head/mane visible above the heart. A few tiny yellow gold sparkles around the head. No extra lion cub needed.
Preserve the reference character identity, face structure, orange mane with flat two-tone orange highlights, white fur and pale blue shadows. Exact thick clean red-orange contour style, clean polished flat graphic shading; no realism, no 3D, no painterly rendering, no redesign.
Keep the same edge-to-edge square background gradient cyan at top to royal blue at bottom; huge centered white circular inset; short thin red-orange radial lines around its inside perimeter; same scale and margins as the references. Large centered lion fills the circle, lower torso fades into soft blue shading at the bottom inside the circle like reference. Keep the heart entirely inside the circle. No text, no lettering, no price, no watermark, no logo. The illustration should look like the same illustrator made a new variation of the exact same icon set.
```

