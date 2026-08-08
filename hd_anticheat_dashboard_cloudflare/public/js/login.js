document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const licenseKey = document.getElementById('licenseKey').value.trim();
    const secret = document.getElementById('secret').value;
    const btn = document.getElementById('loginBtn');
    const errEl = document.getElementById('loginError');
    errEl.textContent = '';
    btn.disabled = true;

    try {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ licenseKey, secret }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Login failed.');

        localStorage.setItem('hdac_token', data.token);
        localStorage.setItem('hdac_license', licenseKey.toUpperCase());
        window.location.href = 'dashboard.html';
    } catch (err) {
        errEl.textContent = err.message;
        btn.disabled = false;
    }
});
