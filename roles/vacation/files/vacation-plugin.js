/**
 * Postsible Vacation & Forwarding Manager - SnappyMail Integration
 * Places the Vacation button directly after the
 * "Create folder" + "Folders" btn-group in the sidebar.
 * Upgrade-safe: 4 fallback strategies.
 */

(function () {
    'use strict';

    const VACATION_URL = '/vacation/';
    const BUTTON_ID    = 'postsible-vacation-btn';
    const OVERLAY_ID   = 'postsible-vacation-overlay';

    // ── Modal overlay ──────────────────────────────────────────────────────────

    function createOverlay() {
        if (document.getElementById(OVERLAY_ID)) return;

        const style = document.createElement('style');
        style.textContent = `
            #${OVERLAY_ID} {
                position: fixed; inset: 0; z-index: 99999;
                display: flex; align-items: center; justify-content: center;
            }
            #${OVERLAY_ID} .pv-backdrop {
                position: absolute; inset: 0;
                background: rgba(0,0,0,.55); backdrop-filter: blur(2px);
            }
            #${OVERLAY_ID} .pv-modal {
                position: relative; z-index: 1;
                width: min(860px, 96vw); height: min(920px, 92vh);
                background: #fff; border-radius: 10px;
                box-shadow: 0 8px 40px rgba(0,0,0,.28);
                display: flex; flex-direction: column; overflow: hidden;
            }
            #${OVERLAY_ID} .pv-header {
                background: #0082c9; color: #fff;
                padding: 0 16px; height: 48px;
                display: flex; align-items: center; gap: 10px; flex-shrink: 0;
            }
            #${OVERLAY_ID} .pv-title {
                flex: 1; font-size: 15px; font-weight: 600;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            }
            #${OVERLAY_ID} .pv-close {
                background: rgba(255,255,255,.18);
                border: 1px solid rgba(255,255,255,.35);
                color: #fff; width: 30px; height: 30px;
                border-radius: 50%; cursor: pointer; font-size: 14px;
                display: flex; align-items: center; justify-content: center;
                transition: background .15s;
            }
            #${OVERLAY_ID} .pv-close:hover { background: rgba(255,255,255,.32); }
            #${OVERLAY_ID} .pv-frame { flex: 1; border: none; width: 100%; }
        `;
        document.head.appendChild(style);

        const overlay = document.createElement('div');
        overlay.id = OVERLAY_ID;
        overlay.innerHTML = `
            <div class="pv-backdrop"></div>
            <div class="pv-modal">
                <div class="pv-header">
                    <span class="pv-title">✈️ Vacation & Forwarding Manager</span>
                    <button class="pv-close" aria-label="Close">✕</button>
                </div>
                <iframe class="pv-frame" src="" title="Vacation & Forwarding Manager"></iframe>
            </div>`;
        document.body.appendChild(overlay);

        const close = () => { overlay.remove(); style.remove(); };
        overlay.querySelector('.pv-close').addEventListener('click', close);
        overlay.querySelector('.pv-backdrop').addEventListener('click', close);
        document.addEventListener('keydown', function esc(e) {
            if (e.key === 'Escape') { close(); document.removeEventListener('keydown', esc); }
        });
        requestAnimationFrame(() => {
            overlay.querySelector('.pv-frame').src = VACATION_URL;
        });
    }

    // ── Sidebar button ─────────────────────────────────────────────────────────
    // Styled as a full-width row matching SnappyMail's sidebar link style

    function createButton() {
        const wrap = document.createElement('div');
        wrap.id = BUTTON_ID;
        wrap.className = 'btn-group hide-on-panel-disabled';

        const btn = document.createElement('a');
        btn.href      = '#';
        btn.className = 'btn';
        btn.title     = 'Vacation & Forwarding Manager';
        btn.style.cssText = `
            display: flex;
            align-items: center;
            gap: 7px;
            width: 100%;
            text-decoration: none;
            color: inherit;
            font-size: 13px;
        `;
        btn.innerHTML = `<span style="font-size:15px;line-height:1">✈</span>
                         <span data-i18n="VACATION/TITLE">Vacation/Forwarding</span>`;

        btn.addEventListener('click', e => {
            e.preventDefault();
            createOverlay();
        });

        wrap.appendChild(btn);
        return wrap;
    }

    function injectButton() {
        if (document.getElementById(BUTTON_ID)) return false;

        // Strategy 1 (primary): insert directly after the btn-group that contains
        // "Create folder" (icon-folder-add) and "Folders" (configureFolders)
        const folderBtnGroup = document.querySelector(
            '.btn-group.hide-on-panel-disabled:has(a.icon-folder-add)'
        );
        if (folderBtnGroup) {
            folderBtnGroup.insertAdjacentElement('afterend', createButton());
            return true;
        }

        // Strategy 2: :has() not supported – find via icon-folder-add parent
        const folderAddBtn = document.querySelector('a.icon-folder-add');
        if (folderAddBtn) {
            const parent = folderAddBtn.closest('.btn-group, div');
            if (parent) {
                parent.insertAdjacentElement('afterend', createButton());
                return true;
            }
        }

        // Strategy 3: after b-toolbar
        const bToolbar = document.querySelector('.b-folders .b-toolbar');
        if (bToolbar) {
            bToolbar.insertAdjacentElement('afterend', createButton());
            return true;
        }

        // Strategy 4: prepend to b-content
        const bContent = document.querySelector('.b-folders .b-content');
        if (bContent) {
            bContent.insertAdjacentElement('beforebegin', createButton());
            return true;
        }

        return false;
    }

    // ── Poll until SnappyMail finishes async KnockoutJS rendering ─────────────

    let attempts = 0;
    const timer = setInterval(() => {
        if (injectButton()) {
            clearInterval(timer);
            return;
        }
        if (++attempts > 60) {
            clearInterval(timer);
            console.warn('[Postsible] Vacation button: SnappyMail DOM anchor not found after 30s.');
        }
    }, 500);

})();

