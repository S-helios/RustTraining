// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

(() => {
    const darkThemes = ['ayu', 'navy', 'coal'];
    const lightThemes = ['light', 'rust'];

    const classList = document.getElementsByTagName('html')[0].classList;

    let lastThemeWasLight = true;
    for (const cssClass of classList) {
        if (darkThemes.includes(cssClass)) {
            lastThemeWasLight = false;
            break;
        }
    }

    const theme = lastThemeWasLight ? 'default' : 'dark';
    mermaid.initialize({ startOnLoad: true, theme });

    // mdBook changes page colors without recreating SVGs. Reload after a theme
    // choice so Mermaid renders with matching light/dark colors. The selector
    // works with mdBook 0.5's prefixed theme-button IDs.
    document.querySelectorAll('#mdbook-theme-list .theme').forEach((button) => {
        button.addEventListener('click', () => {
            window.setTimeout(() => window.location.reload(), 0);
        });
    });
})();
