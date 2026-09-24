# In-app purchase review screenshots

Captured September 16, 2026 from the rebuilt native iOS app with the copy from commit `04c0724`. Device: dedicated iPhone 13 Pro Max simulator, iOS 18.6, Xcode 16.4, UUID `57AC112F-5DC7-4277-82FC-E6EFD5E42EEE`.

Each image is a direct `xcrun simctl io ... screenshot --type=jpeg` capture: 1284 × 2778 pixels, RGB, no alpha, no resizing or compositing. This size is listed in Apple's [6.5-inch screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

The screenshots show actual app UI using the existing DEBUG-only cohort and tier preview arguments. They illustrate the service offered; they are not evidence of live StoreKit purchases or completed sandbox acceptance testing. Production enforcement remains off.

| App Store Connect product | Screenshot | Screen state |
|---|---|---|
| `braversearch.trial.14day` | [trial-14day.jpg](trial-14day.jpg) | Free 14-day trial offer and terms |
| `braversearch.lifetime.coffee` | [lifetime-coffee.jpg](lifetime-coffee.jpg) | $4.99 lifetime unlock |
| `braversearch.lifetime.supporter` | [lifetime-supporter.jpg](lifetime-supporter.jpg) | $9.99 lifetime unlock |
| `braversearch.lifetime.champion` | [lifetime-champion.jpg](lifetime-champion.jpg) | $24.99 Big-hearted lion unlock |
| `braversearch.lifetime.hero` | [lifetime-hero.jpg](lifetime-hero.jpg) | $49.99 lifetime unlock |
| `braversearch.lifetime.legend` | [lifetime-legend.jpg](lifetime-legend.jpg) | $99.99 lifetime unlock |

Upload to each product's **Review Information → Screenshot**, beside Review Notes. These are review assets, not the optional square promotional image.

## Upload status

Automated uploads of the new trial and coffee JPEGs returned App Store Connect's generic “There was an error uploading your screenshot. Try again later.” No successful attachment is claimed. A manual upload of the same coffee file was requested to distinguish a browser-automation problem from an Apple-side rejection. The remaining four images are ready locally.
