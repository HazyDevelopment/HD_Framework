(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'HD_Framework';
    const $ = (id) => document.getElementById(id);

    let maxSlots = 5;
    let starterFlats = [];
    let selectedFlatId = null;
    let selectedDay = null;

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function escapeHtml(str) {
        const d = document.createElement('div');
        d.textContent = str == null ? '' : String(str);
        return d.innerHTML;
    }

    function showScreen(name) {
        document.querySelectorAll('.screen').forEach((el) => el.classList.add('hidden'));
        $(`screen-${name}`).classList.remove('hidden');
    }

    // ═══════════════════════════ CHARACTER SELECT ══════════════════════
    function renderSelect(characters) {
        showScreen('select');
        const grid = $('slotGrid');
        grid.innerHTML = '';

        characters.forEach((c) => {
            const card = document.createElement('div');
            card.className = 'slot-card';
            const initials = ((c.firstname || '?')[0] + (c.lastname || '?')[0]).toUpperCase();
            card.innerHTML = `
                <button class="slot-delete" title="Delete">✕</button>
                <div class="slot-avatar">${initials}</div>
                <div class="slot-name">${escapeHtml(c.firstname)} ${escapeHtml(c.lastname)}</div>
                <div class="slot-job">${escapeHtml(c.jobLabel || 'Unemployed')}</div>`;
            card.addEventListener('click', () => post('selectCharacter', { citizenid: c.citizenid }));
            const delBtn = card.querySelector('.slot-delete');
            delBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                if (delBtn.dataset.armed === '1') {
                    post('deleteCharacter', { citizenid: c.citizenid });
                } else {
                    delBtn.dataset.armed = '1';
                    delBtn.textContent = '✓';
                    delBtn.title = 'Click again to confirm delete';
                    setTimeout(() => { delBtn.dataset.armed = '0'; delBtn.textContent = '✕'; }, 3000);
                }
            });
            grid.appendChild(card);
        });

        if (characters.length < maxSlots) {
            const newCard = document.createElement('div');
            newCard.className = 'slot-card new-slot';
            newCard.innerHTML = `<div class="slot-avatar">+</div><div class="slot-name">New Character</div>`;
            newCard.addEventListener('click', openCreate);
            grid.appendChild(newCard);
        }
    }

    // ═══════════════════════════ CHARACTER CREATE ══════════════════════
    function openCreate() {
        showScreen('create');
        $('cFirstName').value = '';
        $('cLastName').value = '';
        $('cGender').value = 'Male';
        selectedFlatId = null;
        selectedDay = null;
        buildDobSelects();
        post('getStarterFlats');
        renderFlats();
    }

    function buildDobSelects() {
        const now = new Date();
        const currentYear = now.getFullYear();
        const minYear = currentYear - 90;
        const maxYear = currentYear - 16;

        const yearSel = $('cDobYear');
        yearSel.innerHTML = '';
        for (let y = maxYear; y >= minYear; y--) {
            const opt = document.createElement('option');
            opt.value = y;
            opt.textContent = y;
            yearSel.appendChild(opt);
        }
        yearSel.value = currentYear - 25;

        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        const monthSel = $('cDobMonth');
        monthSel.innerHTML = '';
        months.forEach((m, i) => {
            const opt = document.createElement('option');
            opt.value = i + 1;
            opt.textContent = m;
            monthSel.appendChild(opt);
        });
        monthSel.value = 1;

        yearSel.addEventListener('change', buildCalendar);
        monthSel.addEventListener('change', buildCalendar);
        buildCalendar();
    }

    function buildCalendar() {
        const year = parseInt($('cDobYear').value, 10);
        const month = parseInt($('cDobMonth').value, 10); // 1-12
        const daysInMonth = new Date(year, month, 0).getDate();
        const firstWeekday = new Date(year, month - 1, 1).getDay(); // 0 = Sunday

        const grid = $('calendarGrid');
        grid.innerHTML = '';
        ['S', 'M', 'T', 'W', 'T', 'F', 'S'].forEach((d) => {
            const head = document.createElement('div');
            head.className = 'calendar-day blank';
            head.style.visibility = 'visible';
            head.style.cursor = 'default';
            head.style.background = 'none';
            head.style.color = '#9AA1AB';
            head.style.fontSize = '10px';
            head.textContent = d;
            grid.appendChild(head);
        });

        for (let i = 0; i < firstWeekday; i++) {
            const blank = document.createElement('div');
            blank.className = 'calendar-day blank';
            grid.appendChild(blank);
        }

        if (selectedDay && selectedDay > daysInMonth) selectedDay = null;

        for (let day = 1; day <= daysInMonth; day++) {
            const btn = document.createElement('button');
            btn.className = 'calendar-day' + (day === selectedDay ? ' selected' : '');
            btn.textContent = day;
            btn.addEventListener('click', () => { selectedDay = day; buildCalendar(); });
            grid.appendChild(btn);
        }
    }

    function renderFlats() {
        const grid = $('flatGrid');
        grid.innerHTML = '';
        if (!starterFlats.length) {
            grid.innerHTML = '<div class="form-error">No starter flats available right now.</div>';
            return;
        }
        starterFlats.forEach((f) => {
            const tile = document.createElement('button');
            tile.className = 'flat-tile' + (f.id === selectedFlatId ? ' selected' : '');
            tile.textContent = f.label;
            tile.addEventListener('click', () => { selectedFlatId = f.id; renderFlats(); });
            grid.appendChild(tile);
        });
    }

    $('createBackBtn').addEventListener('click', () => showScreen('select'));

    function showCreateError(msg) {
        const el = $('createError');
        el.textContent = msg;
        el.classList.toggle('hidden', !msg);
    }

    $('createSubmitBtn').addEventListener('click', () => {
        const firstname = $('cFirstName').value.trim();
        const lastname = $('cLastName').value.trim();
        if (!firstname || !lastname) { showCreateError('Enter a first and last name.'); return; }
        if (!selectedDay) { showCreateError('Select a date of birth.'); return; }
        if (!selectedFlatId) { showCreateError('Select a home address.'); return; }
        showCreateError(null);

        post('createCharacter', {
            firstname, lastname,
            gender: $('cGender').value,
            dobYear: $('cDobYear').value,
            dobMonth: $('cDobMonth').value,
            dobDay: selectedDay,
            flatId: selectedFlatId,
        });
    });

    // ═══════════════════════════ NUI MESSAGE ROUTER ═════════════════════
    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'showSelect':
                maxSlots = d.maxSlots || 5;
                $('root').classList.remove('hidden');
                renderSelect(d.characters || []);
                break;
            case 'starterFlats':
                starterFlats = d.flats || [];
                renderFlats();
                break;
            case 'hide':
                $('root').classList.add('hidden');
                break;
        }
    });
})();
