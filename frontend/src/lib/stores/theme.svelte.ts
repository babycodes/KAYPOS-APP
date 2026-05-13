// ============================================
// KAYPOS — Theme Store (Dark/Light Mode)
// Persisted via localStorage, auto-detect system pref
// ============================================

import { browser } from '$app/environment';

/** Key used in localStorage */
const STORAGE_KEY = 'kaypos-theme';

export type Theme = 'light' | 'dark';

/**
 * Get the initial theme: localStorage > system preference > dark default
 */
function getInitialTheme(): Theme {
	if (browser) {
		const stored = localStorage.getItem(STORAGE_KEY);
		if (stored === 'light' || stored === 'dark') return stored;
		if (window.matchMedia('(prefers-color-scheme: light)').matches) return 'light';
	}
	return 'dark'; // default dark for POS kiosk
}

/** Current theme state */
let currentTheme = $state<Theme>(getInitialTheme());

/**
 * Apply theme class to <html> element
 */
function applyTheme(theme: Theme) {
	if (!browser) return;
	const html = document.documentElement;
	if (theme === 'dark') {
		html.classList.add('dark');
	} else {
		html.classList.remove('dark');
	}
	localStorage.setItem(STORAGE_KEY, theme);
}

/**
 * Theme store object with reactive getter and actions
 */
export const themeStore = {
	get current(): Theme {
		return currentTheme;
	},
	get isDark(): boolean {
		return currentTheme === 'dark';
	},
	toggle() {
		currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
		applyTheme(currentTheme);
	},
	set(theme: Theme) {
		currentTheme = theme;
		applyTheme(currentTheme);
	},
	/** Call once on app mount to apply initial theme */
	init() {
		applyTheme(currentTheme);
	}
};
