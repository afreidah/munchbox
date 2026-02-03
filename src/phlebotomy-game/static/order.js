// -------------------------------------------------------------------------------
// Phlebotomy Game - Order of Draw Mode
//
// Project: Munchbox / Author: Alex Freidah
//
// Drag-and-drop game for practicing the order of draw sequence. Tubes must be
// placed into numbered slots in the correct order (1-7).
// -------------------------------------------------------------------------------

let placedTubes = {};

// -------------------------------------------------------------------------
// INITIALIZATION
// -------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', initOrderGame);

function initOrderGame() {
    placedTubes = {};

    document.getElementById('results').classList.add('hidden');
    document.getElementById('feedback').textContent = '';
    document.getElementById('feedback').className = 'feedback';
    document.getElementById('check-btn').disabled = true;

    // Reset drop zones
    document.querySelectorAll('.drop-zone').forEach(zone => {
        zone.classList.remove('correct', 'incorrect');
        const existing = zone.querySelector('.draggable-tube');
        if (existing) existing.remove();
    });

    createTubes();
    setupDragListeners();
}

// -------------------------------------------------------------------------
// TUBE CREATION
// -------------------------------------------------------------------------

function createTubes() {
    const bank = document.getElementById('tube-bank');
    bank.innerHTML = '';

    const tubes = shuffle([...TUBES]);

    tubes.forEach((tube, idx) => {
        const el = document.createElement('div');
        el.className = 'draggable-tube';
        el.draggable = true;
        el.dataset.order = tube.order;
        el.dataset.color = tube.color;
        el.dataset.name = tube.name;
        el.dataset.id = idx;
        el.innerHTML = `<span>${tube.name}</span>`;

        const bg = getTubeBackground(tube.color);
        if (bg.includes('gradient')) {
            el.style.background = bg;
        } else {
            el.style.backgroundColor = bg;
        }

        bank.appendChild(el);
    });
}

// -------------------------------------------------------------------------
// DRAG AND DROP
// -------------------------------------------------------------------------

function setupDragListeners() {
    // Draggable tubes
    document.querySelectorAll('.draggable-tube').forEach(tube => {
        tube.addEventListener('dragstart', handleDragStart);
        tube.addEventListener('dragend', handleDragEnd);
    });

    // Drop zones
    document.querySelectorAll('.drop-zone').forEach(zone => {
        zone.addEventListener('dragover', handleDragOver);
        zone.addEventListener('dragleave', handleDragLeave);
        zone.addEventListener('drop', handleDrop);
    });

    // Tube bank (for returning tubes)
    const bank = document.getElementById('tube-bank');
    bank.addEventListener('dragover', handleDragOver);
    bank.addEventListener('drop', handleBankDrop);
}

function handleDragStart(e) {
    e.target.classList.add('dragging');
    e.dataTransfer.setData('text/plain', e.target.dataset.id);
    e.dataTransfer.effectAllowed = 'move';
}

function handleDragEnd(e) {
    e.target.classList.remove('dragging');
}

function handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    if (e.currentTarget.classList.contains('drop-zone')) {
        e.currentTarget.classList.add('drag-over');
    }
}

function handleDragLeave(e) {
    e.currentTarget.classList.remove('drag-over');
}

function handleDrop(e) {
    e.preventDefault();
    e.currentTarget.classList.remove('drag-over');

    const tubeId = e.dataTransfer.getData('text/plain');
    const tube = document.querySelector(`.draggable-tube[data-id="${tubeId}"]`);
    const zone = e.currentTarget;

    if (!tube || !zone.classList.contains('drop-zone')) return;

    // Check if zone already has a tube
    const existingTube = zone.querySelector('.draggable-tube');
    if (existingTube) {
        // Return existing tube to bank
        document.getElementById('tube-bank').appendChild(existingTube);
        existingTube.classList.remove('in-zone');
        delete placedTubes[zone.dataset.order];
    }

    // Place new tube
    zone.appendChild(tube);
    tube.classList.add('in-zone');
    placedTubes[zone.dataset.order] = tube.dataset.order;

    updateCheckButton();
}

function handleBankDrop(e) {
    e.preventDefault();

    const tubeId = e.dataTransfer.getData('text/plain');
    const tube = document.querySelector(`.draggable-tube[data-id="${tubeId}"]`);

    if (!tube) return;

    // Find and clear the zone this tube was in
    const parentZone = tube.closest('.drop-zone');
    if (parentZone) {
        delete placedTubes[parentZone.dataset.order];
    }

    document.getElementById('tube-bank').appendChild(tube);
    tube.classList.remove('in-zone');

    updateCheckButton();
}

function updateCheckButton() {
    const allPlaced = Object.keys(placedTubes).length === 7;
    document.getElementById('check-btn').disabled = !allPlaced;
}

// -------------------------------------------------------------------------
// CHECK ANSWER
// -------------------------------------------------------------------------

function checkOrder() {
    let correctCount = 0;
    const zones = document.querySelectorAll('.drop-zone');

    zones.forEach(zone => {
        const tube = zone.querySelector('.draggable-tube');
        if (!tube) return;

        const zoneOrder = parseInt(zone.dataset.order);
        const tubeOrder = parseInt(tube.dataset.order);

        if (zoneOrder === tubeOrder) {
            zone.classList.add('correct');
            zone.classList.remove('incorrect');
            correctCount++;
        } else {
            zone.classList.add('incorrect');
            zone.classList.remove('correct');
        }
    });

    const feedback = document.getElementById('feedback');

    if (correctCount === 7) {
        feedback.textContent = 'Perfect! All tubes in correct order!';
        feedback.className = 'feedback correct';
        showOrderResults(true, correctCount);
    } else {
        feedback.textContent = `${correctCount} out of 7 correct. Try again!`;
        feedback.className = 'feedback incorrect';
    }
}

function showOrderResults(perfect, count) {
    if (perfect) {
        document.getElementById('results').classList.remove('hidden');
        document.getElementById('results-title').textContent = 'Perfect Score!';
        document.getElementById('results-message').textContent =
            'You placed all tubes in the correct order of draw.';
    }
}

// -------------------------------------------------------------------------
// EVENT LISTENERS
// -------------------------------------------------------------------------

document.getElementById('check-btn').addEventListener('click', checkOrder);
document.getElementById('reset-btn').addEventListener('click', initOrderGame);
