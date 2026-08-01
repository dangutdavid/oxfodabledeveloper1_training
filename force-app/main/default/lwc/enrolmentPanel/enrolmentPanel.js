import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createEnrolment from '@salesforce/apex/EnrolmentController.createEnrolment';

export default class EnrolmentPanel extends NavigationMixin(LightningElement) {
    @api cohort;
    studentId = null;
    isWorking = false;

    get hasCohort() {
        return !!this.cohort;
    }

    get seatsLabel() {
        return `${this.cohort.Seats_Remaining__c} seat(s) remaining`;
    }

    get enrolDisabled() {
        return !this.studentId || this.isWorking;
    }

    handleStudentChange(event) {
        this.studentId = event.detail.recordId;
    }

    async handleEnrol() {
        this.isWorking = true;
        try {
            const enrolment = await createEnrolment({
                cohortId:  this.cohort.Id,
                studentId: this.studentId,
                status:    'Confirmed'
            });

            this.showToast('Success', `Enrolment ${enrolment.Name} created.`, 'success');
            this.studentId = null;

            // Tell the page to refresh the cohort list (the seat count has changed).
            this.dispatchEvent(new CustomEvent('enrolled', {
                detail: enrolment.Id, bubbles: true, composed: true
            }));

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: enrolment.Id,
                    objectApiName: 'Enrolment__c',
                    actionName: 'view'
                }
            });

        } catch (error) {
            const message = error?.body?.message || 'Something went wrong. Please try again.';
            this.showToast('Could not enrol student', message, 'error');
        } finally {
            this.isWorking = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
