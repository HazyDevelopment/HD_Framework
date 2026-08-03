(function () {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_housing';

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function fmtPrice(n) {
        return '£' + Math.floor(n).toLocaleString('en-GB');
    }

    let pendingBuzz = null;
    $('buzzAccept').addEventListener('click', () => {
        if (!pendingBuzz) return;
        post('buzzRespond', { propertyId: pendingBuzz.propertyId, visitorSrc: pendingBuzz.visitorSrc, accept: true });
        $('buzzPrompt').classList.add('hidden');
        pendingBuzz = null;
    });
    $('buzzDecline').addEventListener('click', () => {
        if (!pendingBuzz) return;
        post('buzzRespond', { propertyId: pendingBuzz.propertyId, visitorSrc: pendingBuzz.visitorSrc, accept: false });
        $('buzzPrompt').classList.add('hidden');
        pendingBuzz = null;
    });

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'buzz') {
            pendingBuzz = { propertyId: d.propertyId, visitorSrc: d.visitorSrc };
            $('buzzName').textContent = d.visitorName || 'Someone';
            $('buzzPrompt').classList.remove('hidden');
            return;
        }
        if (d.action !== 'brochure') return;

        const el = $('brochure');
        if (!d.show) {
            el.classList.add('hidden');
            return;
        }

        el.classList.remove('hidden');
        $('brochureId').textContent = d.id || '';
        $('brochureLabel').textContent = d.label || '';
        $('brochureSize').textContent = d.size || '';

        const tag = $('brochureTag');
        const price = $('brochurePrice');
        if (d.registered) {
            tag.textContent = 'FOR SALE';
            tag.classList.remove('unlisted');
            price.textContent = fmtPrice(d.price || 0);
            price.classList.remove('unlisted');
        } else {
            tag.textContent = 'NOT LISTED';
            tag.classList.add('unlisted');
            price.textContent = 'Not yet listed for sale';
            price.classList.add('unlisted');
        }
    });
})();
