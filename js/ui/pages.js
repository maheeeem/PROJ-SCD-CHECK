// Profile menu functionality
import { handleLogout } from './app.js';

export function initProfileMenu() {
    const profileMenuBtn = document.getElementById('profileMenuBtn');
    const profileDropdown = document.getElementById('profileDropdown');
    const logoutLink = document.querySelector('.dropdown-item:last-child');
    
    if (profileMenuBtn && profileDropdown) {
        profileMenuBtn.addEventListener('click', (event) => {
            event.stopPropagation();
            profileDropdown.classList.toggle('show');
        });

        document.addEventListener('click', (event) => {
            if (!profileMenuBtn.contains(event.target) && !profileDropdown.contains(event.target)) {
                profileDropdown.classList.remove('show');
            }
        });
    }

    if (logoutLink) {
        logoutLink.addEventListener('click', async (event) => {
            event.preventDefault();
            closeProfileDropdown();
            await handleLogout();
        });
    }
}

export function closeProfileDropdown() {
    const profileDropdown = document.getElementById('profileDropdown');
    if (profileDropdown) {
        profileDropdown.classList.remove('show');
    }
}
