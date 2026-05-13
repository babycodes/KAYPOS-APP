export function ripple(node: HTMLElement) {
	node.style.position = 'relative';
	node.style.overflow = 'hidden';

	function handlePointerDown(event: PointerEvent) {
		const rect = node.getBoundingClientRect();
		const x = event.clientX - rect.left;
		const y = event.clientY - rect.top;

		const circle = document.createElement('span');
		const diameter = Math.max(rect.width, rect.height) * 2;
		const radius = diameter / 2;

		circle.style.width = circle.style.height = `${diameter}px`;
		circle.style.left = `${x - radius}px`;
		circle.style.top = `${y - radius}px`;
		circle.style.position = 'absolute';
		circle.style.borderRadius = '50%';
		circle.style.transform = 'scale(0)';
		// cubic-bezier(0.4, 0, 0.2, 1) is the standard Material Design easing
		circle.style.transition = 'transform 300ms cubic-bezier(0.4, 0, 0.2, 1), opacity 300ms cubic-bezier(0.4, 0, 0.2, 1)';
		circle.style.backgroundColor = 'currentColor';
		circle.style.opacity = '0.2';
		circle.style.pointerEvents = 'none';

		node.appendChild(circle);

		// Trigger animation in the next frame
		requestAnimationFrame(() => {
			circle.style.transform = 'scale(1)';
		});

		function cleanup() {
			circle.style.opacity = '0';
			setTimeout(() => {
				circle.remove();
			}, 300);
			window.removeEventListener('pointerup', cleanup);
			window.removeEventListener('pointercancel', cleanup);
			window.removeEventListener('pointerleave', cleanup);
		}

		window.addEventListener('pointerup', cleanup);
		window.addEventListener('pointercancel', cleanup);
		window.addEventListener('pointerleave', cleanup);
	}

	node.addEventListener('pointerdown', handlePointerDown);

	return {
		destroy() {
			node.removeEventListener('pointerdown', handlePointerDown);
		}
	};
}
