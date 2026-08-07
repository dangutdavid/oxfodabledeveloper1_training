import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';
import isGuest from '@salesforce/user/isGuest';

// LWR "Build Your Own" ships no profile/logout menu - this is the site's
// header, navigation and auth link on every page.
import labelLogOut from '@salesforce/label/c.Portal_Log_Out';
import labelLogIn from '@salesforce/label/c.Portal_Log_In';
import labelHome from '@salesforce/label/c.Portal_Nav_Home';
import labelProfile from '@salesforce/label/c.Portal_Nav_Profile';

export default class PortalHeader extends LightningElement {
    // Each page instance sets its own heading via the component's
    // Builder properties - see js-meta.xml - so one component serves
    // every page without hard-coding "Home" text into a Profile page.
    @api heroTitle = 'Your learning, in one place.';
    @api heroSubtitle =
        'Track your enrolments, settle your invoices, and download your certificates - whenever you need them.';

    isGuest = isGuest;
    labels = {
        logOut: labelLogOut, logIn: labelLogIn,
        home: labelHome, profile: labelProfile
    };

    get authUrl() {
        return this.isGuest ? `${basePath}/login` : `${basePath}/secur/logout.jsp`;
    }
    get authLabel() {
        return this.isGuest ? this.labels.logIn : this.labels.logOut;
    }
    get homeUrl() {
        return `${basePath}/`;
    }
    get profileUrl() {
        return `${basePath}/profile`;
    }
    get onProfilePage() {
        return typeof window !== 'undefined'
            && window.location.pathname.replace(/\/+$/, '').endsWith('/profile');
    }
    get homeLinkClass() {
        return this.onProfilePage ? 'nav-link' : 'nav-link active';
    }
    get profileLinkClass() {
        return this.onProfilePage ? 'nav-link active' : 'nav-link';
    }
}
