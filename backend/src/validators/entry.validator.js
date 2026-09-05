const categoryPatterns = {
  single_digit: /^\d$/,
  jodi: /^\d{2}$/,
  single_panna: /^\d{3}$/,
  patti: /^\d{3}$/,
  half_sangam: /^\d-\d{3}$|^\d{3}-\d$/,
  full_sangam: /^\d{3}-\d{3}$/,
};

module.exports = { categoryPatterns };
