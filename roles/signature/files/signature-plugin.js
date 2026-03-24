/**
 * Postsible Signature Manager - SnappyMail Integration
 * Places the Signature button directly below the Vacation button in the sidebar.
 * Same overlay mechanism as vacation-plugin.js.
 */

(function () {
    'use strict';

    const SIGNATURE_URL = '/signature/';
    const BUTTON_ID     = 'postsible-signature-btn';
    const OVERLAY_ID    = 'postsible-signature-overlay';

    // ── Modal overlay ──────────────────────────────────────────────────────────

    function createOverlay() {
        if (document.getElementById(OVERLAY_ID)) return;

        const style = document.createElement('style');
        style.textContent = `
            #${OVERLAY_ID} {
                position: fixed; inset: 0; z-index: 99999;
                display: flex; align-items: center; justify-content: center;
            }
            #${OVERLAY_ID} .ps-backdrop {
                position: absolute; inset: 0;
                background: rgba(0,0,0,.55); backdrop-filter: blur(2px);
            }
            #${OVERLAY_ID} .ps-modal {
                position: relative; z-index: 1;
                width: min(960px, 96vw); height: min(940px, 93vh);
                background: #fff; border-radius: 10px;
                box-shadow: 0 8px 40px rgba(0,0,0,.28);
                display: flex; flex-direction: column; overflow: hidden;
            }
            #${OVERLAY_ID} .ps-header {
                background: #0082c9; color: #fff;
                padding: 0 16px; height: 48px;
                display: flex; align-items: center; gap: 10px; flex-shrink: 0;
            }
            #${OVERLAY_ID} .ps-title {
                flex: 1; font-size: 15px; font-weight: 600;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            }
            #${OVERLAY_ID} .ps-close {
                background: rgba(255,255,255,.18);
                border: 1px solid rgba(255,255,255,.35);
                color: #fff; width: 30px; height: 30px;
                border-radius: 50%; cursor: pointer; font-size: 14px;
                display: flex; align-items: center; justify-content: center;
                transition: background .15s;
            }
            #${OVERLAY_ID} .ps-close:hover { background: rgba(255,255,255,.32); }
            #${OVERLAY_ID} .ps-frame { flex: 1; border: none; width: 100%; }
        `;
        document.head.appendChild(style);

        const overlay = document.createElement('div');
        overlay.id = OVERLAY_ID;
        overlay.innerHTML = `
            <div class="ps-backdrop"></div>
            <div class="ps-modal">
                <div class="ps-header">
                    <span class="ps-title">✍️ Signature Manager</span>
                    <button class="ps-close" aria-label="Close">✕</button>
                </div>
                <iframe class="ps-frame" src="" title="Signature Manager"></iframe>
            </div>`;
        document.body.appendChild(overlay);

        const close = () => { overlay.remove(); style.remove(); };
        overlay.querySelector('.ps-close').addEventListener('click', close);
        overlay.querySelector('.ps-backdrop').addEventListener('click', close);
        document.addEventListener('keydown', function esc(e) {
            if (e.key === 'Escape') { close(); document.removeEventListener('keydown', esc); }
        });
        requestAnimationFrame(() => {
            overlay.querySelector('.ps-frame').src = SIGNATURE_URL;
        });
    }

    // ── Sidebar button ─────────────────────────────────────────────────────────

    function createButton() {
        const wrap = document.createElement('div');
        wrap.id = BUTTON_ID;
        wrap.className = 'btn-group hide-on-panel-disabled';

        const btn = document.createElement('a');
        btn.href      = '#';
        btn.className = 'btn';
        btn.title     = 'Signature Manager';
        btn.style.cssText = `
            display: flex;
            align-items: center;
            gap: 7px;
            width: 100%;
            text-decoration: none;
            color: inherit;
            font-size: 13px;
        `;
        btn.innerHTML = `<span style="font-size:15px;line-height:1">✍</span>
                         <span data-i18n="SIGNATURE/TITLE">Signature</span>`;

        btn.addEventListener('click', e => {
            e.preventDefault();
            createOverlay();
        });

        wrap.appendChild(btn);
        return wrap;
    }

    function injectButton() {
        if (document.getElementById(BUTTON_ID)) return false;

        // Strategy 1: insert after the vacation button (preferred – keeps them together)
        const vacationBtn = document.getElementById('postsible-vacation-btn');
        if (vacationBtn) {
            vacationBtn.insertAdjacentElement('afterend', createButton());
            return true;
        }

        // Strategy 2: insert after the folder btn-group (same as vacation fallback)
        const folderBtnGroup = document.querySelector(
            '.btn-group.hide-on-panel-disabled:has(a.icon-folder-add)'
        );
        if (folderBtnGroup) {
            folderBtnGroup.insertAdjacentElement('afterend', createButton());
            return true;
        }

        // Strategy 3: folder-add parent
        const folderAddBtn = document.querySelector('a.icon-folder-add');
        if (folderAddBtn) {
            const parent = folderAddBtn.closest('.btn-group, div');
            if (parent) { parent.insertAdjacentElement('afterend', createButton()); return true; }
        }

        // Strategy 4: b-toolbar
        const bToolbar = document.querySelector('.b-folders .b-toolbar');
        if (bToolbar) {
            bToolbar.insertAdjacentElement('afterend', createButton());
            return true;
        }

        // Strategy 5: b-content
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
        if (injectButton()) { clearInterval(timer); return; }
        if (++attempts > 60) {
            clearInterval(timer);
            console.warn('[Postsible] Signature button: SnappyMail DOM anchor not found after 30s.');
        }
    }, 500);

})();
