// KAYPOS — Auth Store V3 (manual lock with PIN)
import { api } from '$lib/api';

interface User {
	id: number;
	username: string;
	name: string;
	role: 'admin' | 'kasir';
}

function createAuthStore() {
	let token = $state<string | null>(null);
	let user = $state<User | null>(null);
	let locked = $state(false);

	function persistLock() {
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('kaypos_locked', locked ? '1' : '0');
		}
	}

	return {
		get token() { return token; },
		get user() { return user; },
		get isLoggedIn() { return !!token && !!user; },
		get isAuthenticated() { return !!token && !!user && !locked; },
		get isAdmin() { return user?.role === 'admin'; },
		get isLocked() { return locked; },

		async login(creds: { username: string; password: string }) {
			const res = await api.post('/auth/login', creds);
			token = res.token;
			user = res.user;
			locked = false;
			api.setToken(res.token);
			persistLock();
			return res.user;
		},

		lock() {
			locked = true;
			persistLock();
		},

		async unlock(pin: string): Promise<boolean> {
			try {
				await api.post('/auth/verify-pin', { pin });
				locked = false;
				persistLock();
				return true;
			} catch {
				return false;
			}
		},

		// Keep for compatibility but no-op now (no auto-lock)
		resetTimer() {},

		logout() {
			token = null;
			user = null;
			locked = false;
			api.setToken('');
			if (typeof localStorage !== 'undefined') {
				localStorage.removeItem('kaypos_auth');
				localStorage.removeItem('kaypos_locked');
			}
		},

		persist() {
			if (typeof localStorage !== 'undefined' && token && user) {
				localStorage.setItem('kaypos_auth', JSON.stringify({ token, user }));
				persistLock();
			}
		},

		restore(): boolean {
			if (typeof localStorage === 'undefined') return false;
			const saved = localStorage.getItem('kaypos_auth');
			if (!saved) return false;
			try {
				const data = JSON.parse(saved);
				token = data.token;
				user = data.user;
				api.setToken(data.token);
				const wasLocked = localStorage.getItem('kaypos_locked');
				locked = wasLocked === '1';
				return true;
			} catch { return false; }
		}
	};
}

export const authStore = createAuthStore();
