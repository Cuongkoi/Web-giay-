document.querySelectorAll('form[data-stock-product]').forEach(form => {
    const quantity = form.querySelector('input[name="quantity"]');
    const sizes = Array.from(form.querySelectorAll('input[name="variantId"][type="radio"]'));
    const cart = form.hasAttribute('data-stock-cart');
    const submit = form.querySelector('[data-stock-submit]');
    let hint = form.querySelector('[data-stock-hint]');
    if (!hint) {
        hint = document.createElement('small');
        hint.className = 'stock-hint muted';
        hint.setAttribute('role', 'status');
        form.after(hint);
    }
    function render() {
        const selected = sizes.find(size => size.checked);
        const max = cart ? Number(quantity.max) : Number(selected?.dataset.remaining || 0);
        const min = Number(quantity.min);
        quantity.max = max;
        quantity.disabled = !cart && max === 0;
        if (quantity.value !== '') quantity.value = Math.max(min, Math.min(max, Math.floor(Number(quantity.value) || min)));
        form.querySelectorAll('[data-quantity-step]').forEach(button => {
            button.disabled = quantity.disabled || (Number(button.dataset.quantityStep) > 0
                ? Number(quantity.value) >= max : Number(quantity.value) <= min);
        });
        sizes.forEach(size => size.closest('.size').classList.toggle('at-limit', size.checked && Number(quantity.value) >= max));
        if (submit) submit.disabled = !selected || max === 0;
        hint.textContent = cart
            ? `Tối đa ${max} đôi cho size này.${Number(quantity.value) >= max ? ' Đã đạt giới hạn.' : ''}`
            : !selected ? 'Chọn size để xem số lượng còn có thể thêm.'
            : max === 0 ? 'Size này đã hết hàng hoặc bạn đã thêm đủ số lượng vào giỏ.'
            : `Có thể thêm ${max} đôi cho size này.${Number(quantity.value) >= max ? ' Đã đạt giới hạn, không thể tăng thêm.' : ''}`;
    }
    async function refresh() {
        const response = await fetch(`${form.dataset.stockUrl}?productId=${encodeURIComponent(form.dataset.stockProduct)}`, { cache: 'no-store' });
        if (!response.ok) throw new Error('Stock unavailable');
        const inventory = await response.json();
        if (cart) {
            const id = Number(form.querySelector('input[name="variantId"]').value);
            quantity.max = inventory.find(item => item.id === id)?.limit || 0;
        } else {
            sizes.forEach(size => {
                const remaining = inventory.find(item => item.id === Number(size.value))?.remaining || 0;
                size.dataset.remaining = remaining;
                size.disabled = remaining === 0;
                size.closest('.size').classList.toggle('unavailable', remaining === 0);
            });
        }
        render();
    }
    sizes.forEach(size => size.addEventListener('change', () => {
        render();
        refresh().catch(() => { hint.textContent = 'Chưa cập nhật được tồn kho. Hệ thống sẽ kiểm tra lại khi thêm vào giỏ.'; });
    }));
    quantity.addEventListener('input', render);
    quantity.addEventListener('change', () => { if (quantity.value === '') quantity.value = quantity.min; render(); });
    form.querySelectorAll('[data-quantity-step]').forEach(button => button.addEventListener('click', () => {
        quantity.value = Number(quantity.value) + Number(button.dataset.quantityStep);
        render();
    }));
    let sending = false;
    form.addEventListener('submit', async event => {
        event.preventDefault();
        if (sending) return;
        // A zero quantity removes a cart line and never needs stock availability.
        if (cart && Number(quantity.value) === 0) { HTMLFormElement.prototype.submit.call(form); return; }
        sending = true;
        const requested = Number(quantity.value);
        try {
            await refresh();
            if (quantity.disabled || requested !== Number(quantity.value)) {
                hint.textContent += ' Tồn kho vừa thay đổi, vui lòng kiểm tra số lượng và thử lại.';
                return;
            }
            if (form.reportValidity()) HTMLFormElement.prototype.submit.call(form);
        } catch {
            hint.textContent = 'Không kiểm tra được tồn kho. Vui lòng thử lại.';
        } finally { sending = false; }
    });
    render();
    // Refresh when returning from another tab, where this cart may have changed.
    window.addEventListener('focus', () => refresh().catch(() => {}));
});
