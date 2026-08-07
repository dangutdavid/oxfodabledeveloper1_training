# CareerLaunch Extension — Code Pack Manifest

The lab workbooks (Parts A, B and C) deliberately contain **no source code**.
Each coding step names a code pack item. Hand students the matching file from
this repository when they reach that step — or print each file as a one-page
handout labelled with its item number.

All items are real files in this repo, so the pack is always current.

## Part A — Foundations & Money

| Item | Type | Name | Repo file |
|------|------|------|-----------|
| 9.1 | Apex class | `ErrorLogger` | `force-app/main/default/classes/ErrorLogger.cls` |
| 9.2 | Apex trigger | `ErrorLogEventTrigger` | `force-app/main/default/triggers/ErrorLogEventTrigger.trigger` |
| 11.1 | Apex class | `CurrencyService` | `force-app/main/default/classes/CurrencyService.cls` |

## Part B — Payments & Certificates

| Item | Type | Name | Repo file |
|------|------|------|-----------|
| 12.1 | Apex class | `PaymentRequest` | `force-app/main/default/classes/PaymentRequest.cls` |
| 12.2 | Apex class | `PaymentResult` | `force-app/main/default/classes/PaymentResult.cls` |
| 12.3 | Apex class | `IPaymentGateway` | `force-app/main/default/classes/IPaymentGateway.cls` |
| 12.4 | Apex class | `PaymentGatewayStub` | `force-app/main/default/classes/PaymentGatewayStub.cls` |
| 12.5 | Apex class | `PaymentGatewayFactory` | `force-app/main/default/classes/PaymentGatewayFactory.cls` |
| 12.6 | Apex class | `PaymentGatewayHttpClient` | `force-app/main/default/classes/PaymentGatewayHttpClient.cls` |
| 12.7 | Apex class | `InvoiceService` | `force-app/main/default/classes/InvoiceService.cls` |
| 12.8 | Apex class | `PaymentService` | `force-app/main/default/classes/PaymentService.cls` |
| 12.9 | Apex edit | `EnrolmentTriggerHandler` (one new line in `onAfterChange`) | `force-app/main/default/classes/EnrolmentTriggerHandler.cls` |
| 13.1 | Apex class | `CertificateController` | `force-app/main/default/classes/CertificateController.cls` |
| 13.2 | Visualforce page | `CertificatePdf` | `force-app/main/default/pages/CertificatePdf.page` |
| 13.3 | Apex class | `CertificateService` | `force-app/main/default/classes/CertificateService.cls` |

## Part C — Portal & Release

| Item | Type | Name | Repo file |
|------|------|------|-----------|
| 14.1 | Apex class | `StudentPortalController` | `force-app/main/default/classes/StudentPortalController.cls` |
| 14.2 | LWC bundle | `studentEnrolments` (html, js, js-meta.xml) | `force-app/main/default/lwc/studentEnrolments/` |
| 14.3 | LWC bundle | `studentInvoices` (html, js, js-meta.xml) | `force-app/main/default/lwc/studentInvoices/` |
| 15.1 | Apex edit | `TestDataFactory` (add the `createStudent` method) | `force-app/main/default/classes/TestDataFactory.cls` |
| 15.2 | Apex test | `ErrorLoggerTest` | `force-app/main/default/classes/ErrorLoggerTest.cls` |
| 15.3 | Apex test | `CurrencyServiceTest` | `force-app/main/default/classes/CurrencyServiceTest.cls` |
| 15.4 | Apex test | `InvoicePaymentServicesTest` | `force-app/main/default/classes/InvoicePaymentServicesTest.cls` |
| 15.5 | Apex test | `CertificateServiceTest` | `force-app/main/default/classes/CertificateServiceTest.cls` |
| 15.6 | Apex test | `StudentPortalControllerTest` | `force-app/main/default/classes/StudentPortalControllerTest.cls` |

Reference (not handed out): custom labels live in `force-app/main/default/labels/`,
French translations in `force-app/main/default/translations/`, and all objects,
fields, tabs and permission sets under `force-app/main/default/objects/`,
`tabs/` and `permissionsets/` — students build those with clicks, following the
workbook, never by copying XML.
