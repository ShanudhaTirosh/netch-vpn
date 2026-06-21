/* ==========================================================================
   Netch VPN / NovaNetchX — panel theme injection
   Injected into the stock 3x-ui SPA via Nginx sub_filter (before </head>), so
   the official prebuilt panel gets the glassmorphism + brand look WITHOUT a
   source rebuild. Brand: navy #03061D/#02051D, teal #289DB7, slate #2B2D38.
   For a compiled-in version of this theme, use panel-theme/ instead.
   ========================================================================== */

:root {
  --netch-accent: #289DB7;
  --netch-accent-hi: #3FC9E6;
  --netch-accent-lo: #1F7E93;
}

/* AntD v6 ships CSS variables by default — recolor the whole design system's
   primary/link/info to teal in one shot. */
:root,
body,
body.dark,
.ant-app {
  --ant-color-primary: var(--netch-accent) !important;
  --ant-color-primary-hover: var(--netch-accent-hi) !important;
  --ant-color-primary-active: var(--netch-accent-lo) !important;
  --ant-color-primary-bg: rgba(40, 157, 183, 0.16) !important;
  --ant-color-primary-bg-hover: rgba(40, 157, 183, 0.24) !important;
  --ant-color-primary-border: rgba(40, 157, 183, 0.45) !important;
  --ant-color-primary-border-hover: var(--netch-accent) !important;
  --ant-color-primary-text: var(--netch-accent) !important;
  --ant-color-primary-text-hover: var(--netch-accent-hi) !important;
  --ant-color-info: var(--netch-accent) !important;
  --ant-color-link: var(--netch-accent) !important;
  --ant-color-link-hover: var(--netch-accent-hi) !important;
}

/* Dark-only: recolour AntD's surface/fill/border CSS variables to navy so EVERY
   component (inputs, selects, dropdowns, default buttons, modals, drawers,
   tables, checkboxes, date pickers) matches the glass theme instead of the
   stock near-black. Scoped to body.dark so light mode is untouched. */
body.dark,
body.dark .ant-app {
  --ant-color-bg-container: rgba(18, 24, 50, 0.66) !important;   /* inputs, default buttons, selects, cards, cells */
  --ant-color-bg-container-disabled: rgba(255, 255, 255, 0.04) !important;
  --ant-color-bg-elevated: rgba(24, 31, 64, 0.94) !important;    /* modals, drawers, dropdowns, popovers, tooltips, pickers */
  --ant-color-bg-layout: transparent !important;                 /* let the page navy gradient show through */
  --ant-color-bg-spotlight: rgba(10, 14, 34, 0.97) !important;
  --ant-color-bg-mask: rgba(2, 5, 15, 0.62) !important;
  --ant-color-fill: rgba(255, 255, 255, 0.10) !important;
  --ant-color-fill-secondary: rgba(255, 255, 255, 0.08) !important;
  --ant-color-fill-tertiary: rgba(255, 255, 255, 0.06) !important;
  --ant-color-fill-quaternary: rgba(255, 255, 255, 0.04) !important;
  --ant-color-border: rgba(255, 255, 255, 0.14) !important;
  --ant-color-border-secondary: rgba(255, 255, 255, 0.08) !important;
}

/* Brand navy canvas — override the upstream per-page background variables. */
.index-page.is-dark, .clients-page.is-dark, .inbounds-page.is-dark, .xray-page.is-dark,
.settings-page.is-dark, .nodes-page.is-dark, .groups-page.is-dark, .api-docs-page.is-dark,
.hosts-page.is-dark, .login-page.is-dark {
  --bg-page:
    radial-gradient(900px 600px at 12% -8%, rgba(40, 157, 183, 0.16), transparent 60%),
    radial-gradient(800px 700px at 110% 6%, rgba(72, 123, 215, 0.12), transparent 55%),
    linear-gradient(160deg, #03061d 0%, #02051d 100%) !important;
  --bg-card: rgba(20, 26, 54, 0.55) !important;
  background-attachment: fixed;
}
.index-page.is-dark.is-ultra, .clients-page.is-dark.is-ultra, .inbounds-page.is-dark.is-ultra,
.xray-page.is-dark.is-ultra, .settings-page.is-dark.is-ultra, .nodes-page.is-dark.is-ultra,
.groups-page.is-dark.is-ultra, .api-docs-page.is-dark.is-ultra, .hosts-page.is-dark.is-ultra {
  --bg-page:
    radial-gradient(900px 600px at 12% -8%, rgba(40, 157, 183, 0.12), transparent 60%),
    linear-gradient(160deg, #010207 0%, #000 100%) !important;
  --bg-card: rgba(10, 14, 34, 0.62) !important;
}

/* Also paint the body so the login page and any unclassed area sit on navy. */
body.dark {
  background:
    radial-gradient(900px 600px at 12% -8%, rgba(40, 157, 183, 0.16), transparent 60%),
    radial-gradient(800px 700px at 110% 6%, rgba(72, 123, 215, 0.12), transparent 55%),
    linear-gradient(160deg, #03061d 0%, #02051d 100%) !important;
  background-attachment: fixed !important;
}

/* Glassmorphism on the main surfaces. */
body.dark .ant-card,
body.dark .content-shell,
body.dark .ant-modal-content,
body.dark .ant-drawer-content,
body.dark .ant-popover-inner,
body.dark .ant-dropdown-menu,
body.dark .ant-layout-sider,
body.dark .ant-layout-header {
  background: var(--bg-card, rgba(20, 26, 54, 0.55)) !important;
  backdrop-filter: blur(18px) saturate(160%);
  -webkit-backdrop-filter: blur(18px) saturate(160%);
  border: 1px solid rgba(40, 157, 183, 0.18) !important;
}
body.dark .ant-layout,
body.dark .ant-layout-content {
  background: transparent !important;
}

/* Fallback recolour for the most visible accents in case cssVar is disabled. */
.ant-btn-primary { background-color: var(--netch-accent) !important; border-color: var(--netch-accent) !important; }
.ant-btn-primary:hover { background-color: var(--netch-accent-hi) !important; border-color: var(--netch-accent-hi) !important; }
.ant-switch-checked { background: var(--netch-accent) !important; }
.ant-tabs-ink-bar { background: var(--netch-accent) !important; }
.ant-menu-item-selected { color: var(--netch-accent) !important; }
.ant-pagination-item-active { border-color: var(--netch-accent) !important; }
.ant-pagination-item-active a { color: var(--netch-accent) !important; }

/* Graceful fallback when backdrop-filter is unsupported. */
@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  body.dark .ant-card,
  body.dark .ant-layout-sider,
  body.dark .ant-layout-header { background: #0d1230 !important; }
}

/* ---- Sidebar / menu / header (the parts that still looked stock) ---------- */
body.dark .ant-layout-sider,
body.dark .ant-menu.ant-menu-dark,
body.dark .ant-menu-dark .ant-menu-sub,
body.dark .ant-layout-sider-trigger {
  background: linear-gradient(180deg, rgba(8, 12, 34, 0.92), rgba(3, 6, 29, 0.92)) !important;
  border-right: 1px solid rgba(40, 157, 183, 0.15) !important;
}
body.dark .ant-menu-dark .ant-menu-item-selected {
  background: linear-gradient(90deg, rgba(40, 157, 183, 0.30), rgba(40, 157, 183, 0.10)) !important;
  color: #fff !important;
  box-shadow: inset 3px 0 0 var(--netch-accent);
}
body.dark .ant-menu-dark .ant-menu-item-selected .anticon,
body.dark .ant-menu-dark .ant-menu-item:hover .anticon,
body.dark .ant-menu-dark .ant-menu-item:hover { color: var(--netch-accent-hi) !important; }

/* The sidebar brand header bar ("SX-UI" + theme toggles). */
body.dark .ant-layout-sider .ant-layout-header,
body.dark .ant-layout-header {
  background: rgba(3, 6, 29, 0.85) !important;
  border-bottom: 1px solid rgba(40, 157, 183, 0.15) !important;
}

/* Login screen: keep the card glassy and centred on the navy canvas. */
body.dark .login-page,
body.dark .login-page .ant-layout,
body.dark .login-page .ant-layout-content { background: transparent !important; }

/* Inputs/segmented on glass. */
body.dark .ant-input, body.dark .ant-input-affix-wrapper,
body.dark .ant-input-number, body.dark .ant-select-selector,
body.dark .ant-segmented {
  background: rgba(255, 255, 255, 0.04) !important;
  border-color: rgba(255, 255, 255, 0.10) !important;
}
body.dark .ant-input:focus, body.dark .ant-input-affix-wrapper-focused,
body.dark .ant-select-focused .ant-select-selector {
  border-color: var(--netch-accent) !important;
  box-shadow: 0 0 0 2px rgba(40, 157, 183, 0.20) !important;
}

/* ---- Modals / drawers / popups (match the main-UI glass cards) ------------ */
body.dark .ant-modal-content,
body.dark .ant-drawer-content,
body.dark .ant-modal-confirm .ant-modal-content {
  /* Same navy radial-glow gradient + glass as .ant-card, so popups read as
     glass cards floating on the canvas rather than flat dark boxes. */
  background:
    radial-gradient(720px 380px at 50% -12%, rgba(40, 157, 183, 0.30), transparent 60%),
    radial-gradient(560px 460px at 115% 8%, rgba(72, 123, 215, 0.16), transparent 55%),
    linear-gradient(160deg, rgba(30, 39, 78, 0.88) 0%, rgba(15, 21, 48, 0.92) 100%) !important;
  backdrop-filter: blur(26px) saturate(170%) !important;
  -webkit-backdrop-filter: blur(26px) saturate(170%) !important;
  border: 1px solid rgba(40, 157, 183, 0.30) !important;
  box-shadow: 0 24px 70px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.07) !important;
}
/* Blend header/body/footer into the glass instead of separate dark bars. */
body.dark .ant-modal-header,
body.dark .ant-drawer-header,
body.dark .ant-modal-body,
body.dark .ant-drawer-body,
body.dark .ant-modal-footer { background: transparent !important; }
body.dark .ant-modal-header, body.dark .ant-drawer-header { border-bottom: 1px solid rgba(40, 157, 183, 0.14) !important; }
body.dark .ant-modal-footer { border-top: 1px solid rgba(40, 157, 183, 0.14) !important; }
body.dark .ant-modal-title, body.dark .ant-drawer-title { color: #f4f7fb !important; }
body.dark .ant-modal-mask, body.dark .ant-drawer-mask {
  background: rgba(3, 7, 26, 0.50) !important;
  backdrop-filter: blur(4px);
}
body.dark .ant-modal .ant-tabs-tab-active .ant-tabs-tab-btn,
body.dark .ant-drawer .ant-tabs-tab-active .ant-tabs-tab-btn { color: var(--netch-accent) !important; }
body.dark .ant-modal .ant-tabs-top > .ant-tabs-nav::before,
body.dark .ant-drawer .ant-tabs-top > .ant-tabs-nav::before { border-bottom-color: rgba(255,255,255,0.08) !important; }

/* Select / date / cascader popups */
body.dark .ant-select-dropdown,
body.dark .ant-picker-dropdown .ant-picker-panel-container,
body.dark .ant-cascader-dropdown .ant-cascader-menus,
body.dark .ant-tooltip-inner {
  background: rgba(8, 12, 34, 0.97) !important;
  backdrop-filter: blur(18px) saturate(160%);
  -webkit-backdrop-filter: blur(18px) saturate(160%);
  border: 1px solid rgba(40, 157, 183, 0.18) !important;
}
body.dark .ant-select-item-option-selected { background: rgba(40,157,183,.18) !important; }

/* ---- Tables (were near-black; make them navy glass) ----------------------- */
body.dark .ant-table { background: transparent !important; }
body.dark .ant-table-thead > tr > th {
  background: rgba(20, 26, 54, 0.72) !important;
  color: #c2cbda !important;
  border-bottom: 1px solid rgba(40, 157, 183, 0.18) !important;
}
body.dark .ant-table-tbody > tr > td {
  background: transparent !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05) !important;
}
body.dark .ant-table-tbody > tr:hover > td,
body.dark .ant-table-tbody > tr.ant-table-row:hover > td { background: rgba(40, 157, 183, 0.08) !important; }
/* Sticky/fixed columns need an opaque-ish backing so rows don't bleed through. */
body.dark .ant-table-cell-fix-left,
body.dark .ant-table-cell-fix-right { background: #0b1030 !important; }
body.dark .ant-table-thead .ant-table-cell-fix-left,
body.dark .ant-table-thead .ant-table-cell-fix-right { background: #141a39 !important; }
body.dark .ant-table-placeholder,
body.dark .ant-table-placeholder:hover > td { background: transparent !important; }

/* Donation heart / sponsor button — hidden (JS also removes it as a backup). */
body.dark .ant-layout-sider .anticon-heart,
body.dark .ant-layout-header .anticon-heart { display: none !important; }
