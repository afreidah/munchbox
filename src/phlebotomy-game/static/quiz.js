// -------------------------------------------------------------------------------
// Phlebotomy Game - Multiple Choice Quiz Mode
//
// Project: Munchbox / Author: Alex Freidah
//
// Multiple choice quiz mode with randomized questions about tube colors, names,
// contents, and order of draw. Supports keyboard navigation (1-4 keys).
// -------------------------------------------------------------------------------

let questions = [];
let currentIndex = 0;
let score = 0;
let answered = false;

// -------------------------------------------------------------------------
// INITIALIZATION
// -------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', startQuiz);

async function startQuiz() {
    currentIndex = 0;
    score = 0;
    answered = false;

    document.getElementById('quiz-area').classList.remove('hidden');
    document.getElementById('results').classList.add('hidden');
    document.getElementById('feedback').textContent = '';
    document.getElementById('feedback').className = 'feedback';

    questions = generateQuestions(10);
    updateProgress();
    showQuestion();
}

// -------------------------------------------------------------------------
// QUESTION GENERATION
// -------------------------------------------------------------------------

function generateQuestions(count) {
    const questionTypes = [
        generateColorToNameQuestion,
        generateNameToContentsQuestion,
        generateContentsToColorQuestion,
        generateOrderToTubeQuestion
    ];

    const generated = [];
    for (let i = 0; i < count; i++) {
        const genFunc = questionTypes[Math.floor(Math.random() * questionTypes.length)];
        generated.push(genFunc());
    }
    return generated;
}

function generateColorToNameQuestion() {
    const tube = TUBES[Math.floor(Math.random() * TUBES.length)];
    const options = [tube.name];

    while (options.length < 4) {
        const other = TUBES[Math.floor(Math.random() * TUBES.length)];
        if (!options.includes(other.name)) {
            options.push(other.name);
        }
    }

    return {
        question: `What is the name of the ${tube.color} tube?`,
        options: shuffle(options),
        answer: tube.name
    };
}

function generateNameToContentsQuestion() {
    const tube = TUBES[Math.floor(Math.random() * TUBES.length)];
    const options = [tube.contents];

    while (options.length < 4) {
        const other = TUBES[Math.floor(Math.random() * TUBES.length)];
        if (!options.includes(other.contents)) {
            options.push(other.contents);
        }
    }

    return {
        question: `What does the ${tube.name} contain?`,
        options: shuffle(options),
        answer: tube.contents
    };
}

function generateContentsToColorQuestion() {
    const tube = TUBES[Math.floor(Math.random() * TUBES.length)];
    const options = [tube.color];

    while (options.length < 4) {
        const other = TUBES[Math.floor(Math.random() * TUBES.length)];
        if (!options.includes(other.color)) {
            options.push(other.color);
        }
    }

    return {
        question: `Which tube contains ${tube.contents}?`,
        options: shuffle(options),
        answer: tube.color
    };
}

function generateOrderToTubeQuestion() {
    const tube = TUBES[Math.floor(Math.random() * TUBES.length)];
    const answer = `${tube.color} (${tube.name})`;
    const options = [answer];

    while (options.length < 4) {
        const other = TUBES[Math.floor(Math.random() * TUBES.length)];
        const optStr = `${other.color} (${other.name})`;
        if (!options.includes(optStr)) {
            options.push(optStr);
        }
    }

    return {
        question: `Which tube is drawn ${getOrdinal(tube.order)} in the order of draw?`,
        options: shuffle(options),
        answer: answer
    };
}

// -------------------------------------------------------------------------
// DISPLAY
// -------------------------------------------------------------------------

function showQuestion() {
    if (currentIndex >= questions.length) {
        showResults();
        return;
    }

    answered = false;
    const q = questions[currentIndex];

    document.getElementById('question-text').textContent = q.question;
    document.getElementById('feedback').textContent = '';
    document.getElementById('feedback').className = 'feedback';
    document.getElementById('next-btn').disabled = true;

    const optionsContainer = document.getElementById('options');
    optionsContainer.innerHTML = '';

    q.options.forEach((opt, idx) => {
        const btn = document.createElement('button');
        btn.className = 'option-btn';
        btn.textContent = `${idx + 1}. ${opt}`;
        btn.onclick = () => selectAnswer(opt, btn);
        optionsContainer.appendChild(btn);
    });
}

function selectAnswer(selected, btn) {
    if (answered) return;
    answered = true;

    const q = questions[currentIndex];
    const correct = selected === q.answer;
    const feedback = document.getElementById('feedback');
    const buttons = document.querySelectorAll('.option-btn');

    buttons.forEach(b => {
        b.disabled = true;
        if (b.textContent.includes(q.answer)) {
            b.classList.add('correct');
        }
    });

    if (correct) {
        score++;
        btn.classList.add('correct');
        feedback.textContent = 'Correct!';
        feedback.className = 'feedback correct';
    } else {
        btn.classList.add('incorrect');
        feedback.textContent = `Incorrect. The answer is: ${q.answer}`;
        feedback.className = 'feedback incorrect';
    }

    document.getElementById('score').textContent = score;
    document.getElementById('next-btn').disabled = false;
    updateProgress();
}

function updateProgress() {
    const progress = ((currentIndex + 1) / questions.length) * 100;
    document.getElementById('progress').style.width = `${progress}%`;
    document.getElementById('total').textContent = questions.length;
}

function showResults() {
    document.getElementById('quiz-area').classList.add('hidden');
    document.getElementById('results').classList.remove('hidden');

    document.getElementById('final-score').textContent = score;
    document.getElementById('final-total').textContent = questions.length;

    const percentage = Math.round((score / questions.length) * 100);
    document.getElementById('score-percentage').textContent = `${percentage}%`;
}

// -------------------------------------------------------------------------
// EVENT LISTENERS
// -------------------------------------------------------------------------

document.getElementById('next-btn').addEventListener('click', () => {
    currentIndex++;
    showQuestion();
});

// Keyboard navigation
document.addEventListener('keydown', (e) => {
    if (answered && e.key === 'Enter') {
        currentIndex++;
        showQuestion();
        return;
    }

    if (!answered && e.key >= '1' && e.key <= '4') {
        const idx = parseInt(e.key) - 1;
        const buttons = document.querySelectorAll('.option-btn');
        if (buttons[idx]) {
            buttons[idx].click();
        }
    }
});
