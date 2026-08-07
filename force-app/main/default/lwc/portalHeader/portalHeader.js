import { LightningElement } from 'lwc';
import basePath from '@salesforce/community/basePath';
import isGuest from '@salesforce/user/isGuest';

import labelLogOut from '@salesforce/label/c.Portal_Log_Out';
import labelLogIn from '@salesforce/label/c.Portal_Log_In';

export default class PortalHeader extends LightningElement {
    isGuest = isGuest;
    labels = { logOut: labelLogOut, logIn: labelLogIn };

    get authUrl() {
        return this.isGuest ? `${basePath}/login` : `${basePath}/secur/logout.jsp`;
    }

    get authLabel() {
        return this.isGuest ? this.labels.logIn : this.labels.logOut;
    }
}
