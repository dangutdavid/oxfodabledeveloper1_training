import { LightningElement, wire } from 'lwc';
import getMyProfile from '@salesforce/apex/StudentPortalController.getMyProfile';

import labelTitle from '@salesforce/label/c.Portal_My_Profile';

export default class StudentProfile extends LightningElement {
    labels = { title: labelTitle };
    profile;
    error;

    @wire(getMyProfile)
    wiredProfile({ data, error }) {
        if (data) {
            this.profile = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Could not load your profile.';
            this.profile = undefined;
        }
    }
}
