import { LightningElement } from 'lwc';
import basePath from '@salesforce/community/basePath';
import isGuest from '@salesforce/user/isGuest';

// LWR "Build Your Own" ships no profile/logout menu - this fills the gap.
import labelLogOut from '@salesforce/label/c.Portal_Log_Out';
import labelLogIn from '@salesforce/label/c.Portal_Log_In';

export default class PortalLogout extends LightningElement {
    isGuest = isGuest;
    labels = { logOut: labelLogOut, logIn: labelLogIn };

    get logoutUrl() {
        return `${basePath}/secur/logout.jsp`;
    }

    get loginUrl() {
        return `${basePath}/login`;
    }
}
