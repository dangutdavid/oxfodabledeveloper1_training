import { LightningElement } from 'lwc';

export default class EnrolmentConsole extends LightningElement {
    selectedCohort;

    handleCohortSelected(event) {
        this.selectedCohort = event.detail;
    }

    handleEnrolled() {
        const explorer = this.template.querySelector('c-cohort-explorer');
        if (explorer) {
            explorer.refresh();
        }
    }
}
