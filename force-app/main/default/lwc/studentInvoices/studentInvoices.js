import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyInvoices from '@salesforce/apex/StudentPortalController.getMyInvoices';
import payInvoice from '@salesforce/apex/StudentPortalController.payInvoice';

import labelTitle from '@salesforce/label/c.Portal_My_Invoices';
import labelEmpty from '@salesforce/label/c.Portal_No_Records';
import labelPayNow from '@salesforce/label/c.Portal_Pay_Now';
import labelPaymentSuccess from '@salesforce/label/c.Portal_Payment_Success';

export default class StudentInvoices extends LightningElement {
    labels = { title: labelTitle, empty: labelEmpty, payNow: labelPayNow };
    invoices;
    error;
    payingId = null;
    wiredResult;

    @wire(getMyInvoices)
    wiredInvoices(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.invoices = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Could not load your invoices.';
            this.invoices = undefined;
        }
    }

    get hasInvoices() {
        return !!this.invoices?.length;
    }

    get isEmpty() {
        return this.invoices && this.invoices.length === 0;
    }

    async handlePay(event) {
        const invoiceId = event.target.dataset.id;
        this.payingId = invoiceId;
        try {
            const result = await payInvoice({ invoiceId });
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: labelPaymentSuccess,
                    message: `Ref: ${result.transactionId}`,
                    variant: 'success'
                }));
                await refreshApex(this.wiredResult);
            } else {
                this.showError(result.errorMessage);
            }
        } catch (error) {
            this.showError(error?.body?.message || 'Payment failed. Please try again.');
        } finally {
            this.payingId = null;
        }
    }

    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Payment not taken', message, variant: 'error'
        }));
    }
}
