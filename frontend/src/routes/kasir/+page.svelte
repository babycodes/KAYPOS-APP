<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';
	import { authStore } from '$lib/stores/auth.svelte';
	import ProductCard from '$lib/components/ProductCard.svelte';
	import CartItem from '$lib/components/CartItem.svelte';
	import UnitSelector from '$lib/components/UnitSelector.svelte';
	import PaymentDialog from '$lib/components/PaymentDialog.svelte';
	import ReceiptModal from '$lib/components/ReceiptModal.svelte';
	import LockScreen from '$lib/components/LockScreen.svelte';
	import ThemeToggle from '$lib/components/ThemeToggle.svelte';
	import InputDialog from '$lib/components/InputDialog.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	// ===== STATE =====
	let products = $state<any[]>([]);
	let categories = $state<any[]>([]);
	let cart = $state<any[]>([]);
	let selectedCategory = $state<number | null>(null);
	let searchQuery = $state('');
	let unitSelectorProduct = $state<any | null>(null);
	let showPayment = $state(false);
	let receiptData = $state<{ transaction: any; details: any[] } | null>(null);
	let showProfile = $state(false);
	let showDashboard = $state(false);
	let cartOpen = $state(false);
	let showSearch = $state(false);
	let showHistory = $state(false);

	let profileMsg = $state('');
	let todayStats = $state<any>({ total_transactions: 0, total_sales: 0, avg_transaction: 0 });
	let todayTxList = $state<any[]>([]);
	let txHistory = $state<any[]>([]);
	let showHeldCarts = $state(false);
	let showLogoutConfirm = $state(false);
	let lowStockItems = $state<any[]>([]);
	let showLowStock = $state(false);
	let pendingPayment = $state<number | null>(null);
	let toastMsg = $state('');
	let toastTimer: ReturnType<typeof setTimeout> | null = null;

	function showToast(msg: string) {
		toastMsg = msg;
		if (toastTimer) clearTimeout(toastTimer);
		toastTimer = setTimeout(() => { toastMsg = ''; }, 3000);
	}

	// ===== HOLD / PARK SYSTEM (API-backed, shared across devices) =====
	interface HeldCart { id: number; label: string; cart_data: any[]; total: number; created_by_name: string; created_at: string; }
	let heldCarts = $state<HeldCart[]>([]);
	let activeCartLabel = $state<string | null>(null);
	let activeCartHeldId = $state<number | null>(null); // DB id of recalled cart
	let pollTimer: ReturnType<typeof setInterval> | null = null;
	const MAX_HELD = 10;

	async function loadHeldCarts() {
		try { heldCarts = await api.get('/held-carts'); } catch { heldCarts = []; }
	}

	function startPolling() {
		if (pollTimer) clearInterval(pollTimer);
		pollTimer = setInterval(loadHeldCarts, 5000);
	}

	function stopPolling() {
		if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
	}
	// ===== DIALOG STATE FOR PARK =====
	let parkDialog = $state({ show: false, title: '', message: '', placeholder: '', defaultValue: '', onSubmit: (_v: string) => {} });
	let parkAlert = $state({ show: false, title: '', message: '' });

	function showParkAlert(title: string, message: string) {
		parkAlert = { show: true, title, message };
	}

	function holdCart() {
		if (cart.length === 0) return;
		if (activeCartLabel) {
			// Re-hold with same name — no dialog needed
			doHoldCart(activeCartLabel);
		} else {
			// Show input dialog for name
			parkDialog = {
				show: true,
				title: '🛒 Tahan Transaksi',
				message: 'Beri nama untuk antrian ini',
				placeholder: 'Nama pembeli...',
				defaultValue: `Pembeli ${heldCarts.length + 1}`,
				onSubmit: (val: string) => {
					const label = val.trim() || `Pembeli ${heldCarts.length + 1}`;
					doHoldCart(label);
				}
			};
		}
	}

	async function doHoldCart(label: string) {
		const total = cart.reduce((s: number, i: any) => s + i.unit_price * i.quantity, 0);
		try {
			await api.post('/held-carts', { label, cart_data: cart, total });
			if (activeCartHeldId) {
				await api.delete(`/held-carts/${activeCartHeldId}`).catch(() => {});
				activeCartHeldId = null;
			}
			cart = [];
			activeCartLabel = null;
			cartOpen = false;
			await loadHeldCarts();
		} catch (e: any) { showParkAlert('Gagal', e.message); }
	}

	async function recallCart(held: HeldCart) {
		if (cart.length > 0) {
			const curLabel = activeCartLabel || 'Pembeli aktif';
			const curTotal = cart.reduce((s: number, i: any) => s + i.unit_price * i.quantity, 0);
			try {
				await api.post('/held-carts', { label: curLabel, cart_data: cart, total: curTotal });
				if (activeCartHeldId) {
					await api.delete(`/held-carts/${activeCartHeldId}`).catch(() => {});
				}
			} catch (e: any) { showParkAlert('Gagal', e.message); return; }
		}
		await api.delete(`/held-carts/${held.id}`).catch(() => {});
		cart = held.cart_data;
		activeCartLabel = held.label;
		activeCartHeldId = held.id;
		showHeldCarts = false;
		await loadHeldCarts();
	}

	async function deleteHeldCart(id: number) {
		try { await api.delete(`/held-carts/${id}`); await loadHeldCarts(); } catch {}
	}

	let cartTotal = $derived(cart.reduce((sum: number, i: any) => sum + i.unit_price * i.quantity, 0));
	let cartCount = $derived(cart.reduce((sum: number, i: any) => sum + i.quantity, 0));
	let filteredProducts = $derived(
		products.filter((p: any) => {
			const matchCat = !selectedCategory || p.category_id === selectedCategory;
			const matchSearch = !searchQuery || p.name.toLowerCase().includes(searchQuery.toLowerCase());
			return matchCat && matchSearch;
		})
	);

	// ===== INIT =====
	onMount(() => {
		if (!authStore.isLoggedIn && !authStore.restore()) { goto('/login'); return; }
		loadData();
		loadDashboard();
		loadHeldCarts();
		loadLowStock();
		startPolling();
		window.addEventListener('click', handleActivity);
		window.addEventListener('keydown', handleActivity);
		window.addEventListener('touchstart', handleActivity);
		window.addEventListener('beforeunload', autoSaveCart);
		document.addEventListener('visibilitychange', handleVisibility);
		return () => { stopPolling(); };
	});

	onDestroy(() => {
		if (typeof window !== 'undefined') {
			window.removeEventListener('click', handleActivity);
			window.removeEventListener('keydown', handleActivity);
			window.removeEventListener('touchstart', handleActivity);
			window.removeEventListener('beforeunload', autoSaveCart);
			document.removeEventListener('visibilitychange', handleVisibility);
		}
	});

	function handleActivity() { authStore.resetTimer(); }

	// Auto-save cart to park when app is closed/hidden
	function handleVisibility() {
		if (document.visibilityState === 'hidden') autoSaveCart();
	}

	function autoSaveCart() {
		if (cart.length === 0) return;
		// Save to localStorage as emergency backup
		try {
			const total = cart.reduce((s: number, c: any) => s + c.quantity * c.unit_price, 0);
			const nextNum = heldCarts.length + 1;
			const label = `Antrian ${nextNum}`;
			// Use sendBeacon for reliability on page unload
			const token = authStore.token || '';
			const payload = JSON.stringify({ label, cart_data: cart, total });
			const blob = new Blob([payload], { type: 'application/json' });
			// Try sendBeacon first (works on unload)
			const apiBase = '/api';
			const headers = { type: 'application/json' };
			const sent = navigator.sendBeacon(
				`${apiBase}/held-carts?token=${token}`,
				new Blob([payload], headers)
			);
			if (sent) {
				cart = [];
			}
		} catch {}
	}

	async function loadData() {
		try {
			const [p, c] = await Promise.all([api.get('/products'), api.get('/categories')]);
			products = p; categories = c;
		} catch {}
	}

	async function loadDashboard() {
		try {
			const [stats, txRes] = await Promise.all([api.get('/transactions/today'), api.get('/transactions?limit=10')]);
			todayStats = stats;
			todayTxList = txRes.data || [];
		} catch {}
	}

	// ===== CART =====
	function calcUnitPrice(product: any, unitName: string): number {
		const unit = product.units?.find((u: any) => u.unit_name === unitName);
		if (!unit) return 0;
		return unit.price / unit.qty_per_unit;
	}

	function handleProductSelect(product: any) {
		if (product.units?.length > 1) { unitSelectorProduct = product; }
		else { addToCart(product, product.units?.[0]?.unit_name || 'pcs', 1); }
	}

	// Calculate qty reserved in held/parked carts for a product
	function getHeldQty(productId: number): number {
		return heldCarts.reduce((sum, hc) => {
			const items = hc.cart_data || [];
			return sum + items.filter((i: any) => i.product?.id === productId).reduce((s: number, i: any) => s + (i.quantity || 0), 0);
		}, 0);
	}

	function getAvailableStock(product: any): number {
		const stock = product.stock_quantity ?? Infinity;
		if (stock === Infinity) return Infinity;
		return Math.max(0, stock - getHeldQty(product.id));
	}

	function addToCart(product: any, unitName: string, quantity: number) {
		const available = getAvailableStock(product);
		const totalInCart = cart.filter((i: any) => i.product.id === product.id).reduce((s: number, i: any) => s + i.quantity, 0);
		if (totalInCart + quantity > available) {
			const remaining = Math.max(0, available - totalInCart);
			if (remaining <= 0) { showToast(`⚠️ Stok ${product.name} habis!`); return; }
			quantity = remaining;
			showToast(`⚠️ Stok terbatas, hanya ${remaining} tersisa`);
		}
		const idx = cart.findIndex((i: any) => i.product.id === product.id && i.selected_unit === unitName);
		if (idx >= 0) { cart[idx].quantity += quantity; cart = [...cart]; }
		else { cart = [...cart, { product, selected_unit: unitName, quantity, unit_price: calcUnitPrice(product, unitName) }]; }
		unitSelectorProduct = null;
	}

	function getStockForItem(i: number) { return getAvailableStock(cart[i]?.product || {}); }
	function getTotalCartQty(productId: number) { return cart.filter((c: any) => c.product.id === productId).reduce((s: number, c: any) => s + c.quantity, 0); }

	function incrementItem(i: number) {
		const stock = getStockForItem(i);
		const totalInCart = getTotalCartQty(cart[i].product.id);
		if (totalInCart >= stock) { showToast(`⚠️ Stok ${cart[i].product.name} sudah maksimal (${Math.round(stock)})`); return; }
		cart[i].quantity += 1; cart = [...cart];
	}
	function decrementItem(i: number) { if (cart[i].quantity > 1) { cart[i].quantity -= 1; cart = [...cart]; } }
	function removeItem(i: number) { cart = cart.filter((_: any, idx: number) => idx !== i); }
	function setItemQty(i: number, qty: number) {
		if (qty <= 0) return;
		const stock = getStockForItem(i);
		const otherQty = cart.filter((c: any, idx: number) => idx !== i && c.product.id === cart[i].product.id).reduce((s: number, c: any) => s + c.quantity, 0);
		const maxQty = Math.max(0, stock - otherQty);
		if (qty > maxQty) { qty = maxQty; showToast(`⚠️ Stok maksimal: ${Math.round(maxQty)}`); }
		cart[i].quantity = qty; cart = [...cart];
	}

	async function handleCheckout(paidAmount: number) {
		// Store pending payment, show confirmation — keep cart open
		pendingPayment = paidAmount;
		showPayment = false;
	}

	async function confirmCheckout() {
		if (pendingPayment === null) return;
		try {
			const items = cart.map((c: any) => ({ product_id: c.product.id, unit_name: c.selected_unit, quantity: c.quantity }));
			const result = await api.post('/transactions', { items, paid_amount: pendingPayment });
			receiptData = result;
			pendingPayment = null;
			cart = [];
			activeCartLabel = null;
			activeCartHeldId = null;
			cartOpen = false;
			loadDashboard();
		} catch (e: any) { showToast('❌ ' + e.message); }
	}

	function cancelCheckout() { pendingPayment = null; showPayment = true; }

	function closeReceipt() { receiptData = null; }

	async function loadHistory() {
		try {
			const now = new Date();
			const today = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
			const res = await api.get(`/transactions?date=${today}&limit=50`);
			txHistory = res.data || [];
		} catch { txHistory = []; }
	}

	async function reprintReceipt(txId: number) {
		try {
			const res = await api.get(`/transactions/${txId}`);
			receiptData = res;
			showHistory = false;
		} catch (e: any) { showToast('❌ Gagal memuat data transaksi: ' + e.message); }
	}
	function fmtPrice(n: number) { return n < 1 && n > 0 ? `Rp ${n.toFixed(2)}` : `Rp ${Math.round(n).toLocaleString('id-ID')}`; }

	let profileForm = $state({ name: '', old_password: '', new_password: '', confirm_password: '', old_pin: '', new_pin: '', confirm_pin: '' });

	function openProfile() {
		profileForm = { name: authStore.user?.name || '', old_password: '', new_password: '', confirm_password: '', old_pin: '', new_pin: '', confirm_pin: '' };
		profileMsg = '';
		showProfile = true;
	}

	async function saveName() {
		try {
			if (!profileForm.name || profileForm.name === authStore.user?.name) { profileMsg = 'Tidak ada perubahan nama'; return; }
			await api.put('/auth/profile', { name: profileForm.name });
			authStore.user!.name = profileForm.name;
			authStore.persist();
			profileMsg = '✅ Nama berhasil diubah!';
		} catch (e: any) { profileMsg = '❌ ' + e.message; }
	}

	async function savePassword() {
		try {
			if (!profileForm.new_password) { profileMsg = 'Password baru wajib diisi'; return; }
			await api.put('/auth/profile', { old_password: profileForm.old_password, new_password: profileForm.new_password, confirm_password: profileForm.confirm_password });
			profileMsg = '✅ Password berhasil diubah!';
			profileForm.old_password = ''; profileForm.new_password = ''; profileForm.confirm_password = '';
		} catch (e: any) { profileMsg = '❌ ' + e.message; }
	}

	async function savePin() {
		try {
			if (!profileForm.new_pin) { profileMsg = 'PIN baru wajib diisi'; return; }
			await api.put('/auth/profile', { old_pin: profileForm.old_pin, new_pin: profileForm.new_pin, confirm_pin: profileForm.confirm_pin });
			profileMsg = '✅ PIN berhasil diubah!';
			profileForm.old_pin = ''; profileForm.new_pin = ''; profileForm.confirm_pin = '';
		} catch (e: any) { profileMsg = '❌ ' + e.message; }
	}

	function handleLogout() { showLogoutConfirm = true; }

	async function loadLowStock() {
		try { lowStockItems = await api.get('/inventory/low-stock'); } catch { lowStockItems = []; }
	}
</script>

<svelte:head><title>KAYPOS — Kasir</title></svelte:head>
{#if authStore.isLocked}<LockScreen />{/if}

<div class="flex flex-col bg-md-surface overflow-hidden kasir-shell">
	<!-- App Bar -->
	<header class="shrink-0 bg-md-primary px-4 flex items-center gap-3 safe-top min-h-[48px]">
		<div class="w-7 h-7 rounded-lg bg-white/20 flex items-center justify-center"><span class="text-white font-black text-xs">K</span></div>
		<span class="font-extrabold text-white text-lg tracking-tight">KAYPOS</span>
	</header>

	<!-- Toolbar Row -->
	<div class="shrink-0 flex items-center gap-2 px-3 py-2 bg-md-surface border-b border-md-outline-variant/30">
		<div class="relative flex-1 max-w-[220px]">
			<select class="appearance-none w-full bg-md-surface-container text-md-on-surface text-xs font-semibold pl-3 pr-7 h-9 rounded-xl border border-md-outline-variant/50 outline-none" onchange={(e) => { const v = (e.target as HTMLSelectElement).value; selectedCategory = v === 'all' ? null : Number(v); }}>
				<option value="all">📦 Semua Kategori</option>
				{#each categories as cat (cat.id)}<option value={cat.id}>{cat.icon} {cat.name}</option>{/each}
			</select>
			<svg class="absolute right-2.5 top-1/2 -translate-y-1/2 text-md-on-surface-variant pointer-events-none" xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="m6 9 6 6 6-6"/></svg>
		</div>
		<!-- Desktop: inline search -->
		<div class="hidden md:block flex-1 relative max-w-md">
			<svg class="absolute left-3 top-1/2 -translate-y-1/2 text-md-on-surface-variant" xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
			<input type="text" bind:value={searchQuery} placeholder="Cari produk..." class="w-full h-9 pl-9 pr-3 rounded-xl bg-md-surface-container text-xs text-md-on-surface border border-md-outline-variant/50 focus:border-md-primary focus:outline-none" />
		</div>
		<!-- Desktop action buttons -->
		<div class="hidden md:flex items-center gap-1">
			<button use:ripple class="h-9 px-3 rounded-xl flex items-center gap-1.5 text-xs font-semibold transition-colors {showDashboard ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant hover:bg-md-surface-container-high'}" onclick={() => { showDashboard = !showDashboard; if (showDashboard) loadDashboard(); }}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg> Rekap
			</button>
			<button use:ripple class="h-9 px-3 rounded-xl flex items-center gap-1.5 text-xs font-semibold transition-colors {showHistory ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant hover:bg-md-surface-container-high'}" onclick={() => { showHistory = !showHistory; if (showHistory) loadHistory(); }}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/></svg> Riwayat
			</button>
			{#if lowStockItems.length > 0}
				<button use:ripple class="h-9 px-3 rounded-xl bg-md-error-container text-md-error flex items-center gap-1.5 text-xs font-bold relative" onclick={() => { showLowStock = !showLowStock; }}>
					<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
					Stok Rendah
					<span class="px-1.5 py-0.5 rounded-full bg-md-error text-md-on-error text-[10px] font-bold min-w-[18px] text-center">{lowStockItems.length}</span>
				</button>
			{/if}
			<button use:ripple class="h-9 px-3 rounded-xl bg-md-surface-container text-md-on-surface-variant hover:bg-md-surface-container-high flex items-center gap-1.5 text-xs font-semibold transition-colors" onclick={openProfile}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/></svg> {authStore.user?.name}
			</button>
			{#if authStore.isAdmin}
				<button use:ripple class="h-9 px-3 rounded-xl bg-md-tertiary-container text-md-on-tertiary-container text-xs font-bold flex items-center gap-1.5" onclick={() => goto('/admin')}>
					<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg> Admin
				</button>
			{/if}
			<button use:ripple class="h-9 px-3 rounded-xl bg-md-error-container/50 text-md-error hover:bg-md-error-container flex items-center gap-1.5 text-xs font-semibold transition-colors" onclick={handleLogout}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/></svg> Keluar
			</button>
		</div>
		<div class="flex-1 md:hidden"></div>
		<!-- Held carts indicator -->
		{#if heldCarts.length > 0}
			<button use:ripple class="h-9 px-3 rounded-xl bg-md-secondary-container text-md-on-secondary-container text-xs font-bold flex items-center gap-1.5 relative" onclick={() => showHeldCarts = !showHeldCarts}>
				<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-6.2-8.6"/><path d="M12 7v5l3 3"/></svg>
				<span class="hidden md:inline">Ditahan</span>
				<span class="min-w-5 h-5 rounded-full bg-md-secondary text-md-on-secondary text-[10px] font-bold flex items-center justify-center">{heldCarts.length}</span>
			</button>
		{/if}
		<button use:ripple class="w-9 h-9 rounded-xl bg-md-error-container/50 text-md-error flex items-center justify-center hover:bg-md-error-container transition-colors" onclick={() => authStore.lock()} title="Kunci Layar">
			<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
		</button>
		<ThemeToggle />
	</div>

	<!-- Mobile: Search Bar (slides from top, below toolbar) -->
	{#if showSearch}
		<div class="md:hidden shrink-0 px-3 py-2 bg-md-surface-container/50 border-b border-md-outline-variant/30">
			<div class="flex items-center gap-2">
				<div class="flex-1 relative">
					<svg class="absolute left-3 top-1/2 -translate-y-1/2 text-md-on-surface-variant" xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
					<!-- svelte-ignore a11y_autofocus -->
					<input type="text" bind:value={searchQuery} placeholder="Cari produk..." autofocus class="w-full h-10 pl-9 pr-3 rounded-xl bg-md-surface-container text-sm text-md-on-surface border border-md-outline-variant/50 focus:border-md-primary focus:outline-none" />
				</div>
				<button class="w-9 h-9 rounded-lg bg-md-surface-container flex items-center justify-center text-md-on-surface-variant shrink-0" onclick={() => { showSearch = false; searchQuery = ''; }}>✕</button>
			</div>
		</div>
	{/if}

	<!-- Mobile: Floating Cart FAB (FIXED) -->
	{#if cart.length > 0}
		<button class="md:hidden fixed right-4 z-19 w-14 h-14 rounded-2xl bg-md-primary text-md-on-primary flex items-center justify-center elevation-3 active:scale-95 transition-transform cart-fab" onclick={() => cartOpen = true}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
			<span class="absolute -top-1 -right-1 min-w-5 h-5 px-1 rounded-full bg-md-error text-md-on-error text-[10px] font-bold flex items-center justify-center">{cart.length}</span>
			<span class="absolute -bottom-5 right-0 text-[9px] font-bold text-md-primary bg-md-surface/90 px-1.5 py-0.5 rounded-full whitespace-nowrap backdrop-blur-sm">{fmtPrice(cartTotal)}</span>
		</button>
	{/if}

	<!-- Main Content -->
	<div class="flex-1 flex overflow-hidden">
		<!-- Products (pb-16 on mobile for fixed bottom nav) -->
		<div class="flex-1 overflow-y-auto px-2 md:px-4 pt-2 pb-20 md:pb-2 no-scrollbar">
			<div class="grid grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-1.5 md:gap-3">
				{#each filteredProducts as product (product.id)}<ProductCard {product} onSelect={handleProductSelect} />{/each}
			</div>
			{#if filteredProducts.length === 0}<div class="text-center py-16 text-md-on-surface-variant"><div class="text-3xl mb-2">🔍</div><p class="font-medium text-sm">Produk tidak ditemukan</p></div>{/if}
		</div>

		<!-- Desktop Cart Sidebar -->
		<aside class="hidden md:flex w-[320px] lg:w-[360px] shrink-0 bg-md-surface-container-low border-l border-md-outline-variant/50 flex-col">
			<div class="p-4 border-b border-md-outline-variant/50 flex items-center justify-between">
				<h2 class="font-bold text-md-on-surface flex items-center gap-2">🛒 Keranjang {#if cart.length > 0}<span class="text-xs px-2 py-0.5 rounded-full bg-md-primary text-md-on-primary">{cart.length}</span>{/if}</h2>
				{#if cart.length > 0}<button class="text-xs text-md-error font-semibold" onclick={() => cart = []}>Kosongkan</button>{/if}
			</div>
			<div class="flex-1 overflow-y-auto p-3 space-y-2 no-scrollbar">
				{#if cart.length === 0}<div class="flex flex-col items-center justify-center h-full text-md-on-surface-variant/50"><p class="font-medium text-sm">Keranjang Kosong</p></div>
				{:else}{#each cart as item, i (item.product.id + '-' + item.selected_unit)}<CartItem {item} onIncrement={() => incrementItem(i)} onDecrement={() => decrementItem(i)} onRemove={() => removeItem(i)} onSetQuantity={(qty) => setItemQty(i, qty)} />{/each}{/if}
			</div>
			<div class="p-4 border-t border-md-outline-variant/50">
				<div class="flex items-center justify-between mb-3"><span class="text-sm font-semibold text-md-on-surface-variant">Total</span><span class="text-2xl font-extrabold text-md-primary tabular-nums">{fmtPrice(cartTotal)}</span></div>
				<div class="flex gap-2 mb-2">
					<button use:ripple disabled={cart.length === 0} class="flex-1 h-11 rounded-xl bg-md-secondary-container text-md-on-secondary-container font-bold text-sm disabled:opacity-30 active:scale-[0.98] transition-all flex items-center justify-center gap-1.5" onclick={holdCart}>
						<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.2-8.6"/><path d="M12 7v5l3 3"/></svg> Tahan
					</button>
				</div>
				<button use:ripple disabled={cart.length === 0} class="w-full h-14 rounded-2xl bg-md-primary text-md-on-primary font-bold text-base elevation-1 disabled:opacity-30 active:scale-[0.98] transition-all" onclick={() => showPayment = true}>💳 BAYAR SEKARANG</button>
			</div>
		</aside>
	</div>



	<!-- Mobile Floating Bottom Nav -->
	<nav class="md:hidden fixed z-20 bg-md-surface-bright/95 backdrop-blur-lg rounded-2xl px-2 flex items-center justify-around h-[60px] elevation-3 border border-md-outline-variant/20 safe-bottom-nav">
		<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl transition-colors {showDashboard ? 'text-md-primary' : 'text-md-on-surface-variant'}" onclick={() => { showDashboard = !showDashboard; if (showDashboard) loadDashboard(); }}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
			<span class="text-[9px] font-semibold">Rekap</span>
		</button>
		<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl transition-colors {showHistory ? 'text-md-primary' : 'text-md-on-surface-variant'}" onclick={() => { showHistory = !showHistory; if (showHistory) loadHistory(); }}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/></svg>
			<span class="text-[9px] font-semibold">Riwayat</span>
		</button>
		<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl transition-colors {showSearch ? 'text-md-primary' : 'text-md-on-surface-variant'}" onclick={() => showSearch = !showSearch}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
			<span class="text-[9px] font-semibold">Cari</span>
		</button>
		<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl text-md-on-surface-variant transition-colors" onclick={openProfile}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/></svg>
			<span class="text-[9px] font-semibold">Profil</span>
		</button>
		{#if lowStockItems.length > 0}
			<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl text-md-error relative" onclick={() => showLowStock = true}>
				<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
				<span class="text-[9px] font-bold">Stok!</span>
				<span class="absolute -top-0.5 -right-0.5 w-[18px] h-[18px] rounded-full bg-md-error text-md-on-error text-[9px] font-bold flex items-center justify-center leading-none">{lowStockItems.length}</span>
			</button>
		{/if}
		{#if authStore.isAdmin}
			<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl text-md-tertiary transition-colors" onclick={() => goto('/admin')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>
				<span class="text-[9px] font-bold">Admin</span>
			</button>
		{/if}
		<button use:ripple class="flex flex-col items-center justify-center gap-0.5 w-16 h-12 rounded-xl text-md-on-surface-variant transition-colors" onclick={handleLogout}>
			<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/></svg>
			<span class="text-[9px] font-semibold">Keluar</span>
		</button>
	</nav>

</div>

<!-- Dashboard Overlay -->
{#if showDashboard}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 z-30 bg-black/40" onclick={() => showDashboard = false}></div>
	<div class="fixed inset-x-0 bottom-14 md:bottom-4 z-30 bg-md-surface-bright rounded-2xl md:rounded-2xl p-4 elevation-3 animate-slide-up max-w-lg mx-auto md:mx-4 md:max-w-md md:right-4 md:left-auto md:inset-x-auto">
		<div class="flex justify-between items-center mb-3"><h3 class="font-bold text-sm">📊 Rekap Hari Ini</h3><button class="text-xs text-md-on-surface-variant" onclick={() => showDashboard = false}>✕</button></div>
		<div class="grid grid-cols-3 gap-2">
			<div class="p-2.5 rounded-xl bg-md-primary-container/30"><div class="text-[9px] text-md-on-surface-variant uppercase font-semibold">Penjualan</div><div class="text-sm font-extrabold text-md-primary tabular-nums">{fmtPrice(todayStats.total_sales || 0)}</div></div>
			<div class="p-2.5 rounded-xl bg-md-secondary-container/30"><div class="text-[9px] text-md-on-surface-variant uppercase font-semibold">Transaksi</div><div class="text-sm font-extrabold text-md-secondary tabular-nums">{todayStats.total_transactions || 0}</div></div>
			<div class="p-2.5 rounded-xl bg-md-tertiary-container/30"><div class="text-[9px] text-md-on-surface-variant uppercase font-semibold">Rata-Rata</div><div class="text-sm font-extrabold text-md-tertiary tabular-nums">{fmtPrice(todayStats.avg_transaction || 0)}</div></div>
		</div>
	</div>
{/if}

<!-- Mobile Cart Bottom Sheet -->
{#if cartOpen}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="md:hidden fixed inset-0 z-40 bg-black/50" onclick={() => cartOpen = false}></div>
	<div class="md:hidden fixed inset-x-0 bottom-0 z-50 bg-md-surface-bright rounded-t-3xl max-h-[85vh] flex flex-col elevation-3 animate-slide-up">
		<div class="flex justify-center pt-3 pb-1"><div class="w-10 h-1 rounded-full bg-md-outline-variant"></div></div>
		<div class="px-4 pb-2 flex items-center justify-between border-b border-md-outline-variant/30">
			<h2 class="font-bold text-md-on-surface">🛒 Keranjang <span class="text-xs px-2 py-0.5 rounded-full bg-md-primary text-md-on-primary">{cart.length}</span></h2>
			<div class="flex items-center gap-2">
				{#if cart.length > 0}<button class="text-xs text-md-error font-semibold" onclick={() => cart = []}>Kosongkan</button>{/if}
				<button class="w-8 h-8 rounded-lg bg-md-surface-container flex items-center justify-center text-md-on-surface-variant" onclick={() => cartOpen = false}>✕</button>
			</div>
		</div>
		<div class="flex-1 overflow-y-auto p-3 space-y-2 no-scrollbar">
			{#each cart as item, i (item.product.id + '-' + item.selected_unit)}<CartItem {item} onIncrement={() => incrementItem(i)} onDecrement={() => decrementItem(i)} onRemove={() => removeItem(i)} onSetQuantity={(qty) => setItemQty(i, qty)} />{/each}
		</div>
		<div class="p-4 border-t border-md-outline-variant/50">
			<div class="flex items-center justify-between mb-3"><span class="text-sm font-semibold text-md-on-surface-variant">Total</span><span class="text-xl font-extrabold text-md-primary tabular-nums">{fmtPrice(cartTotal)}</span></div>
			<div class="flex gap-2 mb-2">
				<button use:ripple disabled={cart.length === 0} class="flex-1 h-11 rounded-xl bg-md-secondary-container text-md-on-secondary-container font-bold text-sm disabled:opacity-30 active:scale-[0.98] transition-all flex items-center justify-center gap-1.5" onclick={holdCart}>
					<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.2-8.6"/><path d="M12 7v5l3 3"/></svg> Tahan
				</button>
			</div>
			<button use:ripple disabled={cart.length === 0} class="w-full h-14 rounded-2xl bg-md-primary text-md-on-primary font-bold text-base elevation-1 disabled:opacity-30 active:scale-[0.98] transition-all" onclick={() => showPayment = true}>💳 BAYAR SEKARANG</button>
		</div>
	</div>
{/if}

<!-- Modals -->
{#if unitSelectorProduct}<UnitSelector product={unitSelectorProduct} onConfirm={addToCart} onCancel={() => unitSelectorProduct = null} />{/if}
{#if showPayment}<PaymentDialog total={cartTotal} onConfirm={handleCheckout} onCancel={() => showPayment = false} />{/if}
{#if receiptData}<ReceiptModal transaction={receiptData.transaction} details={receiptData.details} onClose={closeReceipt} />{/if}

{#if showProfile}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center" onclick={(e) => { if (e.target === e.currentTarget) showProfile = false; }}>
		<div class="w-full max-w-sm bg-md-surface-bright rounded-t-2xl md:rounded-2xl p-5 elevation-3 max-h-[90vh] overflow-y-auto no-scrollbar">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-bold">👤 Profil Saya</h3>
				<button class="w-8 h-8 rounded-lg bg-md-surface-container text-md-on-surface-variant flex items-center justify-center" onclick={() => showProfile = false}>✕</button>
			</div>
			{#if profileMsg}<div class="text-sm text-center mb-3 font-medium rounded-lg p-2 {profileMsg.startsWith('✅') ? 'bg-green-500/10 text-green-600' : 'bg-md-error-container text-md-on-error-container'}">{profileMsg}</div>{/if}
			<!-- Name -->
			<div class="mb-4 p-3 rounded-xl bg-md-surface-container/50 border border-md-outline-variant/30">
				<p class="text-xs font-bold text-md-on-surface-variant mb-2">📝 Nama Tampilan</p>
				<input type="text" bind:value={profileForm.name} class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none mb-2" />
				<button use:ripple class="w-full h-9 rounded-lg bg-md-primary text-md-on-primary text-xs font-bold" onclick={saveName}>Simpan Nama</button>
			</div>
			<!-- Password -->
			<div class="mb-4 p-3 rounded-xl bg-md-surface-container/50 border border-md-outline-variant/30">
				<p class="text-xs font-bold text-md-on-surface-variant mb-2">🔑 Ganti Password</p>
				<div class="space-y-2 mb-2">
					<input type="password" bind:value={profileForm.old_password} placeholder="Password Lama" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none" />
					<input type="password" bind:value={profileForm.new_password} placeholder="Password Baru" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none" />
					<input type="password" bind:value={profileForm.confirm_password} placeholder="Konfirmasi Password" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
				<button use:ripple class="w-full h-9 rounded-lg bg-md-secondary text-md-on-secondary text-xs font-bold" onclick={savePassword}>Simpan Password</button>
			</div>
			<!-- PIN -->
			<div class="mb-4 p-3 rounded-xl bg-md-surface-container/50 border border-md-outline-variant/30">
				<p class="text-xs font-bold text-md-on-surface-variant mb-2">🔢 Ganti PIN (6 angka)</p>
				<div class="space-y-2 mb-2">
					<input type="password" bind:value={profileForm.old_pin} placeholder="PIN Lama" maxlength="6" inputmode="numeric" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none text-center tracking-[0.5em]" />
					<input type="password" bind:value={profileForm.new_pin} placeholder="PIN Baru" maxlength="6" inputmode="numeric" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none text-center tracking-[0.5em]" />
					<input type="password" bind:value={profileForm.confirm_pin} placeholder="Konfirmasi PIN" maxlength="6" inputmode="numeric" class="w-full h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none text-center tracking-[0.5em]" />
				</div>
				<button use:ripple class="w-full h-9 rounded-lg bg-md-tertiary text-md-on-tertiary text-xs font-bold" onclick={savePin}>Simpan PIN</button>
			</div>
		</div>
	</div>
{/if}

<!-- Transaction History Modal -->
{#if showHistory}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center" onclick={(e) => { if (e.target === e.currentTarget) showHistory = false; }}>
		<div class="w-full max-w-md bg-md-surface-bright rounded-t-2xl md:rounded-2xl elevation-3 max-h-[85vh] flex flex-col">
			<div class="flex items-center justify-between p-4 border-b border-md-outline-variant/30">
				<h3 class="font-bold text-base flex items-center gap-2">
					<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/></svg>
					Riwayat Hari Ini
				</h3>
				<button class="w-8 h-8 rounded-lg bg-md-surface-container text-md-on-surface-variant flex items-center justify-center" onclick={() => showHistory = false}>✕</button>
			</div>
			<div class="flex-1 overflow-y-auto p-3 space-y-2 no-scrollbar">
				{#if txHistory.length === 0}
					<div class="text-center py-8 text-md-on-surface-variant">
						<p class="text-sm font-medium">Belum ada transaksi hari ini</p>
					</div>
				{:else}
					{#each txHistory as tx}
						<div class="p-3 rounded-xl bg-md-surface-container border border-md-outline-variant/20">
							<div class="flex items-center justify-between mb-1">
								<span class="text-xs font-bold text-md-on-surface">#{tx.id}</span>
								<span class="text-[10px] text-md-on-surface-variant">{tx.created_at?.split(' ')[1]?.slice(0,5) || tx.created_at}</span>
							</div>
							<div class="flex items-center justify-between mb-2">
								<span class="text-xs text-md-on-surface-variant">{tx.cashier_name || '-'}</span>
								<span class="text-sm font-extrabold text-md-primary tabular-nums">{fmtPrice(tx.total_amount)}</span>
							</div>
							<div class="flex items-center justify-between text-[10px] text-md-on-surface-variant mb-2">
								<span>Bayar: {fmtPrice(tx.paid_amount)}</span>
								<span>Kembali: {fmtPrice(tx.change_amount)}</span>
							</div>
							<button use:ripple class="w-full h-8 rounded-lg bg-md-primary-container text-md-on-primary-container text-xs font-bold flex items-center justify-center gap-1.5" onclick={() => reprintReceipt(tx.id)}>
								<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14"/></svg>
								Lihat / Cetak Ulang
							</button>
						</div>
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Held Carts Picker -->
{#if showHeldCarts}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 z-40 bg-black/40" onclick={() => showHeldCarts = false}></div>
	<div class="fixed inset-x-4 md:right-4 md:left-auto md:w-80 top-[120px] z-40 bg-md-surface-bright rounded-2xl p-4 elevation-3 max-h-[60vh] overflow-y-auto no-scrollbar">
		<div class="flex items-center justify-between mb-3">
			<h3 class="font-bold text-sm flex items-center gap-2">
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.2-8.6"/><path d="M12 7v5l3 3"/></svg>
				Transaksi Ditahan ({heldCarts.length})
			</h3>
			<button class="text-xs text-md-on-surface-variant" onclick={() => showHeldCarts = false}>✕</button>
		</div>
		{#if heldCarts.length === 0}
			<p class="text-sm text-md-on-surface-variant text-center py-4">Tidak ada transaksi ditahan</p>
		{:else}
			<div class="space-y-2">
				{#each heldCarts as held}
					<div class="p-3 rounded-xl bg-md-surface-container border border-md-outline-variant/30">
						<div class="flex items-center justify-between mb-1">
							<span class="font-bold text-sm text-md-on-surface">{held.label}</span>
							<span class="text-[10px] text-md-on-surface-variant">{held.created_at?.split(' ')[1]?.slice(0,5) || ''}</span>
						</div>
						<div class="text-xs text-md-on-surface-variant mb-2">{held.cart_data.length} item · {held.created_by_name} — <span class="font-bold text-md-primary">{fmtPrice(held.total)}</span></div>
						<div class="flex gap-2">
							<button use:ripple class="flex-1 h-8 rounded-lg bg-md-primary text-md-on-primary text-xs font-bold" onclick={() => recallCart(held)}>Panggil</button>
							<button use:ripple class="h-8 px-3 rounded-lg bg-md-error-container/50 text-md-error text-xs font-bold" onclick={() => deleteHeldCart(held.id)}>Hapus</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
{/if}

<!-- Park Cart Dialogs -->
<InputDialog
	bind:show={parkDialog.show}
	title={parkDialog.title}
	message={parkDialog.message}
	placeholder={parkDialog.placeholder}
	defaultValue={parkDialog.defaultValue}
	type="input"
	onSubmit={parkDialog.onSubmit}
/>
<InputDialog
	bind:show={parkAlert.show}
	title={parkAlert.title}
	message={parkAlert.message}
	type="alert"
/>

<!-- Logout Confirm -->
{#if showLogoutConfirm}
	<ConfirmDialog title="Logout" message="Yakin ingin logout dari kasir?" confirmText="Ya, Logout" onConfirm={() => { authStore.logout(); goto('/login'); }} onCancel={() => showLogoutConfirm = false} />
{/if}

<!-- Checkout Confirm -->
{#if pendingPayment !== null}
	<ConfirmDialog title="Konfirmasi Transaksi" message="Pastikan semua item dan jumlah pembayaran sudah benar. Transaksi akan langsung tersimpan dan tidak bisa diubah." confirmText="Ya, Proses Pembelian" onConfirm={confirmCheckout} onCancel={cancelCheckout} />
{/if}

<!-- Low Stock Alert Modal -->
{#if showLowStock}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center" onclick={(e) => { if (e.target === e.currentTarget) showLowStock = false; }}>
		<div class="w-full max-w-md bg-md-surface-bright rounded-t-2xl md:rounded-2xl p-5 elevation-3 max-h-[80vh] overflow-y-auto no-scrollbar">
			<div class="flex justify-between items-center mb-3">
				<h3 class="font-bold text-sm text-md-error flex items-center gap-2">⚠️ Stok Rendah ({lowStockItems.length})</h3>
				<button class="w-8 h-8 rounded-lg bg-md-surface-container text-md-on-surface-variant flex items-center justify-center" onclick={() => showLowStock = false}>✕</button>
			</div>
			<p class="text-xs text-md-on-surface-variant mb-3">Produk berikut stoknya rendah. Laporkan ke owner untuk restock.</p>
			<div class="space-y-2">
				{#each lowStockItems as item}
					<div class="flex items-center justify-between p-2.5 rounded-xl bg-md-error-container/10 border border-md-error/20">
						<div>
							<div class="font-semibold text-sm">{item.name}</div>
							<div class="text-[10px] text-md-on-surface-variant">{item.category_name || '-'} · Min: {item.min_stock_alert}</div>
						</div>
						<div class="text-right">
							<div class="text-lg font-extrabold text-md-error tabular-nums">{Math.round(item.stock_quantity)}</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</div>
{/if}

<!-- Toast Notification -->
{#if toastMsg}
	<div class="fixed top-20 left-1/2 -translate-x-1/2 z-[100] px-5 py-3 rounded-2xl bg-md-inverse-surface text-md-inverse-on-surface text-sm font-semibold elevation-3 max-w-[90vw] text-center animate-toast">
		{toastMsg}
	</div>
{/if}

<style>
	.kasir-shell { height: 100dvh; height: 100vh; }
	@supports (height: 100dvh) { .kasir-shell { height: 100dvh; } }
	@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
	.animate-slide-up { animation: slideUp 0.25s ease-out; }
	.safe-top { padding-top: env(safe-area-inset-top, 0px); }
	.safe-bottom-nav {
		bottom: calc(env(safe-area-inset-bottom, 0px) + 12px);
		left: 12px;
		right: 12px;
	}
	.cart-fab {
		bottom: calc(env(safe-area-inset-bottom, 0px) + 100px);
	}
	@keyframes toastIn { from { opacity: 0; transform: translate(-50%, -10px); } to { opacity: 1; transform: translate(-50%, 0); } }
	.animate-toast { animation: toastIn 0.25s ease-out; }
</style>
