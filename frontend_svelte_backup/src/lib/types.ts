// ============================================
// KAYPOS — TypeScript Types (sesuai PRD §6)
// ============================================

/** Kategori produk */
export interface Category {
	id: string;
	name: string;
	icon: string; // emoji or icon identifier
}

/** Produk (tabel `products`) */
export interface Product {
	id: number;
	name: string;
	category_id: string;
	base_price: number;     // harga per base_unit (Rp)
	base_unit: string;      // satuan dasar: 'gram', 'cm', 'pcs'
	barcode?: string;       // kode barcode (opsional)
	units: ProductUnit[];   // satuan-satuan yang tersedia
}

/** Satuan konversi produk (tabel `product_units`) */
export interface ProductUnit {
	id: number;
	unit_name: string;              // 'karung', 'dus', 'meter'
	conversion_multiplier: number;  // contoh: 25000 (1 karung = 25000 gram)
	price_adjustment: number;       // penyesuaian harga (biasanya 0)
}

/** Item dalam keranjang */
export interface CartItem {
	product: Product;
	selected_unit: string;          // unit yang dipilih saat checkout
	quantity: number;
	unit_price: number;             // harga per unit yang dipilih
}

/** Barcode scan result */
export interface BarcodeScanResult {
	barcode: string;
	timestamp: number;
}
