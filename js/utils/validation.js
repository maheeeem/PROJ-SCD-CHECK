// Validation utilities for form inputs

export const validation = {
    /**
     * Validate email format
     * @param {string} email - Email to validate
     * @returns {Object} { valid: boolean, error: string }
     */
    validateEmail(email) {
        if (!email || email.trim() === '') {
            return { valid: false, error: 'Email is required' };
        }

        const trimmedEmail = email.trim();
        
        // Email regex that allows plus signs and standard email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        
        if (!emailRegex.test(trimmedEmail)) {
            return { valid: false, error: 'Please enter a valid email address' };
        }

        return { valid: true, error: null };
    },

    /**
     * Validate password strength
     * @param {string} password - Password to validate
     * @returns {Object} { valid: boolean, error: string, requirements: Object }
     */
    validatePassword(password) {
        if (!password) {
            return { 
                valid: false, 
                error: 'Password is required',
                requirements: {
                    length: false,
                    uppercase: false,
                    lowercase: false,
                    number: false,
                    special: false
                }
            };
        }

        const requirements = {
            length: password.length >= 8,
            uppercase: /[A-Z]/.test(password),
            lowercase: /[a-z]/.test(password),
            number: /[0-9]/.test(password),
            special: /[!@#$%^&*(),.?":{}|<>]/.test(password)
        };

        const allMet = Object.values(requirements).every(req => req);

        if (!allMet) {
            return { 
                valid: false, 
                error: 'Password does not meet all requirements',
                requirements 
            };
        }

        return { valid: true, error: null, requirements };
    },

    /**
     * Check if password meets minimum length
     * @param {string} password - Password to check
     * @returns {boolean}
     */
    isPasswordLengthValid(password) {
        return password && password.length >= 8;
    },

    /**
     * Check if password has uppercase letter
     * @param {string} password - Password to check
     * @returns {boolean}
     */
    hasUppercase(password) {
        return password && /[A-Z]/.test(password);
    },

    /**
     * Check if password has lowercase letter
     * @param {string} password - Password to check
     * @returns {boolean}
     */
    hasLowercase(password) {
        return password && /[a-z]/.test(password);
    },

    /**
     * Check if password has number
     * @param {string} password - Password to check
     * @returns {boolean}
     */
    hasNumber(password) {
        return password && /[0-9]/.test(password);
    },

    /**
     * Check if password has special character
     * @param {string} password - Password to check
     * @returns {boolean}
     */
    hasSpecialCharacter(password) {
        return password && /[!@#$%^&*(),.?":{}|<>]/.test(password);
    },

    /**
     * Validate password confirmation matches
     * @param {string} password - Original password
     * @param {string} confirmPassword - Confirmation password
     * @returns {Object} { valid: boolean, error: string }
     */
    validatePasswordConfirmation(password, confirmPassword) {
        if (!confirmPassword) {
            return { valid: false, error: 'Please confirm your password' };
        }

        if (password !== confirmPassword) {
            return { valid: false, error: 'Passwords do not match' };
        }

        return { valid: true, error: null };
    },

    /**
     * Validate required text field
     * @param {string} value - Value to validate
     * @param {string} fieldName - Name of the field for error message
     * @returns {Object} { valid: boolean, error: string }
     */
    validateRequired(value, fieldName) {
        if (!value || value.trim() === '') {
            return { valid: false, error: `${fieldName} is required` };
        }
        return { valid: true, error: null };
    }
};
