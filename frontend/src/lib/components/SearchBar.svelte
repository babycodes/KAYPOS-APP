<script lang="ts">
	let {
		value = $bindable(''),
		placeholder = 'Cari produk...',
		onSearch
	}: {
		value?: string;
		placeholder?: string;
		onSearch?: (query: string) => void;
	} = $props();

	function handleInput(e: Event) {
		const target = e.target as HTMLInputElement;
		value = target.value;
		onSearch?.(value);
	}

	function clear() {
		value = '';
		onSearch?.('');
	}
</script>

<div class="relative flex items-center w-full max-w-md">
	<!-- Search Icon -->
	<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="absolute left-3.5 text-md-on-surface-variant pointer-events-none">
		<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>
	</svg>
	<input
		type="text"
		{placeholder}
		{value}
		oninput={handleInput}
		class="w-full h-12 pl-11 pr-10 rounded-full bg-md-surface-container text-md-on-surface placeholder:text-md-on-surface-variant/60 border border-md-outline-variant focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20 transition-all duration-200 text-sm font-medium"
	/>
	{#if value}
		<button
			onclick={clear}
			class="absolute right-3 flex items-center justify-center w-7 h-7 rounded-full hover:bg-md-surface-container-high transition-colors"
			aria-label="Hapus pencarian"
		>
			<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-md-on-surface-variant">
				<path d="M18 6 6 18"/><path d="m6 6 12 12"/>
			</svg>
		</button>
	{/if}
</div>
