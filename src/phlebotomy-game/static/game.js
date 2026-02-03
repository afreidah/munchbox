// -------------------------------------------------------------------------------
// Phlebotomy Game - Shared Game Logic
//
// Project: Munchbox / Author: Alex Freidah
//
// Common utilities and data management shared across all game modes. Provides
// tube data access, color mapping, and helper functions.
// -------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// TUBE DATA
// -------------------------------------------------------------------------

const TUBES = [
    { order: 1, color: "blue and red bottles", name: "blood culture", contents: "sodium polyanethol sulfonate (SPS)" },
    { order: 2, color: "light blue", name: "coagulation tube", contents: "sodium citrate" },
    { order: 3, color: "red", name: "non-additive tube", contents: "none" },
    { order: 4, color: "gold/tiger top", name: "SST", contents: "clot activator and gel" },
    { order: 5, color: "light green", name: "PST", contents: "lithium heparin" },
    { order: 5, color: "dark green", name: "heparin tube", contents: "sodium heparin" },
    { order: 6, color: "lavender", name: "EDTA tube", contents: "potassium EDTA" },
    { order: 7, color: "grey", name: "glycolytic inhibitor tube", contents: "potassium oxalate and sodium fluoride" }
];

// -------------------------------------------------------------------------
// COLOR MAPPING
// -------------------------------------------------------------------------

const TUBE_COLORS = {
    "blue and red bottles": "linear-gradient(90deg, #60a5fa 50%, #dc2626 50%)",
    "light blue": "#60a5fa",
    "red": "#dc2626",
    "gold/tiger top": "#eab308",
    "light green": "#4ade80",
    "dark green": "#16a34a",
    "lavender": "#c084fc",
    "grey": "#6b7280"
};

// -------------------------------------------------------------------------
// UTILITIES
// -------------------------------------------------------------------------

// Shuffles an array in place using Fisher-Yates algorithm.
function shuffle(array) {
    const arr = [...array];
    for (let i = arr.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
}

// Gets the ordinal suffix for a number (1st, 2nd, 3rd, etc.)
function getOrdinal(n) {
    const s = ["th", "st", "nd", "rd"];
    const v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

// Normalizes a string for comparison (lowercase, trimmed, simplified)
function normalize(str) {
    return str.toLowerCase().trim().replace(/\s+/g, ' ');
}

// Checks if two strings are similar enough (for partial credit)
function isSimilar(input, answer) {
    const normInput = normalize(input);
    const normAnswer = normalize(answer);

    if (normInput === normAnswer) return true;

    // Check if input contains key parts of the answer
    const keywords = normAnswer.split(' ').filter(w => w.length > 3);
    const matchCount = keywords.filter(kw => normInput.includes(kw)).length;

    return matchCount >= Math.ceil(keywords.length * 0.6);
}

// Gets CSS background style for a tube color.
function getTubeBackground(color) {
    return TUBE_COLORS[color] || "#6b7280";
}

// Gets a unique list of tubes by order (for order-based games).
function getUniqueTubesByOrder() {
    const seen = new Set();
    return TUBES.filter(tube => {
        if (seen.has(tube.order)) return false;
        seen.add(tube.order);
        return true;
    });
}
