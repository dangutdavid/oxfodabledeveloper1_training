import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getActiveCourses from '@salesforce/apex/CohortController.getActiveCourses';
import getOpenCohorts from '@salesforce/apex/CohortController.getOpenCohorts';

const COLUMNS = [
    { label: 'Cohort',     fieldName: 'Name',               type: 'text' },
    { label: 'Course',     fieldName: 'courseName',         type: 'text' },
    { label: 'Starts',     fieldName: 'Start_Date__c',      type: 'date' },
    { label: 'Mode',       fieldName: 'Delivery_Mode__c',   type: 'text' },
    { label: 'Capacity',   fieldName: 'Capacity__c',        type: 'number',
      cellAttributes: { alignment: 'left' } },
    { label: 'Seats left', fieldName: 'Seats_Remaining__c', type: 'number',
      cellAttributes: { alignment: 'left' } }
];

export default class CohortExplorer extends LightningElement {
    columns = COLUMNS;
    selectedCourseId = null;
    courseOptions = [];
    rows = [];
    wiredCohortResult;               // held so we can refreshApex later

    @wire(getActiveCourses)
    wiredCourses({ data, error }) {
        if (data) {
            this.courseOptions = [
                { label: 'All courses', value: '' },
                ...data.map((course) => ({ label: course.Name, value: course.Id }))
            ];
        } else if (error) {
            this.courseOptions = [{ label: 'All courses', value: '' }];
        }
    }

    @wire(getOpenCohorts, { courseId: '$selectedCourseId' })
    wiredCohorts(result) {
        this.wiredCohortResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.map((cohort) => ({
                ...cohort,
                courseName: cohort.Course__r ? cohort.Course__r.Name : ''
            }));
        } else if (error) {
            this.rows = [];
        }
    }

    get hasCohorts() {
        return this.rows && this.rows.length > 0;
    }

    handleCourseChange(event) {
        this.selectedCourseId = event.detail.value ? event.detail.value : null;
    }

    handleRowSelection(event) {
        const selected = event.detail.selectedRows;
        // Data down, events up: tell the parent which cohort was chosen.
        this.dispatchEvent(new CustomEvent('cohortselected', {
            detail: selected.length ? selected[0] : null,
            bubbles: true,
            composed: true
        }));
    }

    @api
    refresh() {
        return refreshApex(this.wiredCohortResult);
    }
}
