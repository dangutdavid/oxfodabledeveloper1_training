import { LightningElement, wire } from 'lwc';
import getMyEnrolments from '@salesforce/apex/StudentPortalController.getMyEnrolments';

// Custom labels resolve in the viewer's language, so the same component
// serves English and French students without a code change.
import labelTitle from '@salesforce/label/c.Portal_My_Enrolments';
import labelEmpty from '@salesforce/label/c.Portal_No_Records';
import labelDownload from '@salesforce/label/c.Portal_Download_Certificate';

export default class StudentEnrolments extends LightningElement {
    labels = { title: labelTitle, empty: labelEmpty, download: labelDownload };
    enrolments;
    error;

    @wire(getMyEnrolments)
    wiredEnrolments({ data, error }) {
        if (data) {
            this.enrolments = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Could not load your enrolments.';
            this.enrolments = undefined;
        }
    }

    get hasEnrolments() {
        return !!this.enrolments?.length;
    }

    get isEmpty() {
        return this.enrolments && this.enrolments.length === 0;
    }
}
