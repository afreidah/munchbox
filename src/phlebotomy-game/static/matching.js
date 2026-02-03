// -------------------------------------------------------------------------------
// Phlebotomy Game - Matching Game Mode
//
// Project: Munchbox / Author: Alex Freidah
//
// Memory-style card matching game. Players flip cards to match tube colors with
// names or contents. Tracks moves and time for scoring.
// -------------------------------------------------------------------------------

let cards = [];
let flippedCards = [];
let matchedPairs = 0;
let totalPairs = 0;
let moves = 0;
let timerInterval = null;
let startTime = null;
let currentMode = null;
let isLocked = false;

// -------------------------------------------------------------------------
// INITIALIZATION
// -------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.addEventListener('click', () => startGame(btn.dataset.mode));
    });
});

function showModeSelect() {
    document.getElementById('mode-select').classList.remove('hidden');
    document.getElementById('matching-area').classList.add('hidden');
    document.getElementById('results').classList.add('hidden');
    stopTimer();
    resetStats();
}

function startGame(mode) {
    currentMode = mode;

    document.getElementById('mode-select').classList.add('hidden');
    document.getElementById('matching-area').classList.remove('hidden');
    document.getElementById('results').classList.add('hidden');

    resetStats();
    createCards(mode);
    startTimer();
}

function restartGame() {
    if (currentMode) {
        startGame(currentMode);
    } else {
        showModeSelect();
    }
}

function resetStats() {
    matchedPairs = 0;
    moves = 0;
    flippedCards = [];
    isLocked = false;
    document.getElementById('moves').textContent = '0';
    document.getElementById('matches').textContent = '0';
}

// -------------------------------------------------------------------------
// CARD CREATION
// -------------------------------------------------------------------------

function createCards(mode) {
    const grid = document.getElementById('card-grid');
    grid.innerHTML = '';

    let pairs = [];

    switch (mode) {
        case 'color-name':
            pairs = TUBES.map(t => ({
                left: { text: t.color, type: 'color', id: t.color },
                right: { text: t.name, type: 'name', id: t.color }
            }));
            break;
        case 'name-contents':
            pairs = TUBES.map(t => ({
                left: { text: t.name, type: 'name', id: t.name },
                right: { text: t.contents, type: 'contents', id: t.name }
            }));
            break;
        case 'color-contents':
            pairs = TUBES.map(t => ({
                left: { text: t.color, type: 'color', id: t.color },
                right: { text: t.contents, type: 'contents', id: t.color }
            }));
            break;
    }

    // Limit to 6 pairs for better gameplay
    pairs = shuffle(pairs).slice(0, 6);
    totalPairs = pairs.length;
    document.getElementById('total-matches').textContent = totalPairs;

    // Create card objects
    cards = [];
    pairs.forEach(pair => {
        cards.push({ ...pair.left, matchId: pair.left.id });
        cards.push({ ...pair.right, matchId: pair.right.id });
    });

    // Shuffle and render
    cards = shuffle(cards);
    cards.forEach((card, idx) => {
        const el = document.createElement('div');
        el.className = 'match-card';
        el.dataset.index = idx;
        el.innerHTML = `
            <span class="card-back">?</span>
            <span class="card-front">${card.text}</span>
        `;
        el.addEventListener('click', () => flipCard(idx, el));
        grid.appendChild(el);
    });
}

// -------------------------------------------------------------------------
// GAME LOGIC
// -------------------------------------------------------------------------

function flipCard(index, element) {
    if (isLocked) return;
    if (element.classList.contains('flipped') || element.classList.contains('matched')) return;
    if (flippedCards.length >= 2) return;

    element.classList.add('flipped');
    flippedCards.push({ index, element, card: cards[index] });

    if (flippedCards.length === 2) {
        moves++;
        document.getElementById('moves').textContent = moves;
        checkMatch();
    }
}

function checkMatch() {
    const [first, second] = flippedCards;
    const isMatch = first.card.matchId === second.card.matchId &&
                   first.card.type !== second.card.type;

    if (isMatch) {
        first.element.classList.add('matched');
        second.element.classList.add('matched');
        matchedPairs++;
        document.getElementById('matches').textContent = matchedPairs;
        flippedCards = [];

        if (matchedPairs === totalPairs) {
            endGame();
        }
    } else {
        isLocked = true;
        setTimeout(() => {
            first.element.classList.remove('flipped');
            second.element.classList.remove('flipped');
            flippedCards = [];
            isLocked = false;
        }, 1000);
    }
}

function endGame() {
    stopTimer();

    setTimeout(() => {
        document.getElementById('matching-area').classList.add('hidden');
        document.getElementById('results').classList.remove('hidden');

        document.getElementById('final-moves').textContent = moves;
        document.getElementById('final-time').textContent = formatTime(getElapsedTime());
    }, 500);
}

// -------------------------------------------------------------------------
// TIMER
// -------------------------------------------------------------------------

function startTimer() {
    startTime = Date.now();
    timerInterval = setInterval(updateTimer, 1000);
}

function stopTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}

function updateTimer() {
    document.getElementById('timer').textContent = formatTime(getElapsedTime());
}

function getElapsedTime() {
    if (!startTime) return 0;
    return Math.floor((Date.now() - startTime) / 1000);
}

function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
}
