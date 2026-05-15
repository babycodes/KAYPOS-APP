// ============================================
// KAYPOS — Barcode Scanner Action (PRD §7)
// Deteksi keyboard wedge: keystroke <50ms + Enter
// ============================================

interface BarcodeScanResult {
	barcode: string;
	timestamp: number;
}

interface BarcodeOptions {
	onScan: (result: BarcodeScanResult) => void;
	maxKeystrokeInterval?: number;
	minLength?: number;
}

/**
 * Svelte action for global barcode scanner detection.
 * Barcode scanners act as keyboard wedges — they type characters
 * very rapidly (<50ms between keystrokes) followed by Enter.
 * 
 * This listener runs in the background and detects this pattern
 * without requiring focus on any specific input field.
 */
export function barcodeScanner(node: HTMLElement, options: BarcodeOptions) {
	let buffer = '';
	let lastKeyTime = 0;
	const maxInterval = options.maxKeystrokeInterval ?? 50;
	const minLength = options.minLength ?? 4;

	function handleKeyDown(event: KeyboardEvent) {
		const now = Date.now();

		// Skip if user is typing in an input/textarea
		const target = event.target as HTMLElement;
		if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) {
			return;
		}

		if (event.key === 'Enter') {
			if (buffer.length >= minLength) {
				// Valid barcode detected
				event.preventDefault();
				event.stopPropagation();
				options.onScan({
					barcode: buffer,
					timestamp: now
				});
			}
			buffer = '';
			lastKeyTime = 0;
			return;
		}

		// Only accept printable single characters
		if (event.key.length !== 1) {
			return;
		}

		// Check timing: if too slow, reset buffer (human typing)
		if (lastKeyTime > 0 && now - lastKeyTime > maxInterval) {
			buffer = '';
		}

		buffer += event.key;
		lastKeyTime = now;
	}

	node.addEventListener('keydown', handleKeyDown, true);

	return {
		update(newOptions: BarcodeOptions) {
			options = newOptions;
		},
		destroy() {
			node.removeEventListener('keydown', handleKeyDown, true);
		}
	};
}
