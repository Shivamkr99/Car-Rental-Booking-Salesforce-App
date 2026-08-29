/**
 * FinancialsHubController
 * Provides financial metrics, transaction ledger, payment processing,
 * and refunds for the paymentManagementHub LWC.
 */
public inherited sharing class FinancialsHubController {

    public class FinancialKPIs {
        @AuraEnabled public Decimal totalRevenue { get; set; }
        @AuraEnabled public Decimal monthRevenue { get; set; }
        @AuraEnabled public Decimal pendingRevenue { get; set; }
        @AuraEnabled public Decimal refundedAmount { get; set; }
        @AuraEnabled public Integer totalTransactions { get; set; }
        @AuraEnabled public Integer paidCount { get; set; }
        @AuraEnabled public Integer pendingCount { get; set; }
        @AuraEnabled public Integer refundedCount { get; set; }
    }

    public class PaymentTransactionWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id bookingId { get; set; }
        @AuraEnabled public String bookingName { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String carName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Date paymentDate { get; set; }
        @AuraEnabled public String paymentMethod { get; set; }
        @AuraEnabled public String paymentStatus { get; set; }
        @AuraEnabled public String transactionReference { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    /**
     * Get financial KPIs overview.
     */
    @AuraEnabled(cacheable=true)
    public static FinancialKPIs getFinancialKPIs() {
        FinancialKPIs kpis = new FinancialKPIs();
        kpis.totalRevenue = 0;
        kpis.monthRevenue = 0;
        kpis.pendingRevenue = 0;
        kpis.refundedAmount = 0;
        kpis.totalTransactions = 0;
        kpis.paidCount = 0;
        kpis.pendingCount = 0;
        kpis.refundedCount = 0;

        Date monthStart = Date.today().toStartOfMonth();
        Date monthEnd = monthStart.addMonths(1);

        for (Payment__c p : [
            SELECT Amount__c, Payment_Status__c, Payment_Date__c
            FROM Payment__c
        ]) {
            kpis.totalTransactions++;
            Decimal amt = p.Amount__c != null ? p.Amount__c : 0;

            if (p.Payment_Status__c == 'Paid') {
                kpis.totalRevenue += amt;
                kpis.paidCount++;
                if (p.Payment_Date__c >= monthStart && p.Payment_Date__c < monthEnd) {
                    kpis.monthRevenue += amt;
                }
            } else if (p.Payment_Status__c == 'Pending') {
                kpis.pendingRevenue += amt;
                kpis.pendingCount++;
            } else if (p.Payment_Status__c == 'Refunded') {
                kpis.refundedAmount += amt;
                kpis.refundedCount++;
            }
        }
        return kpis;
    }

    /**
     * Get list of payment transactions with full context.
     */
    @AuraEnabled(cacheable=true)
    public static List<PaymentTransactionWrapper> getPayments(String statusFilter, String searchKey) {
        String query = 'SELECT Id, Name, Booking__c, Booking__r.Name, Booking__r.Customer__r.First_Name__c, ' +
                       'Booking__r.Customer__r.Last_Name__c, Booking__r.Car__r.Brand__c, Booking__r.Car__r.Car_Model__c, ' +
                       'Amount__c, Payment_Date__c, Payment_Method__c, Payment_Status__c, Transaction_Reference__c, CreatedDate ' +
                       'FROM Payment__c WHERE Id != null ';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += ' AND Payment_Status__c = :statusFilter';
        }

        if (String.isNotBlank(searchKey)) {
            String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (Name LIKE :key OR Transaction_Reference__c LIKE :key OR Booking__r.Name LIKE :key OR Booking__r.Customer__r.First_Name__c LIKE :key OR Booking__r.Customer__r.Last_Name__c LIKE :key)';
        }

        query += ' ORDER BY CreatedDate DESC LIMIT 150';

        List<PaymentTransactionWrapper> results = new List<PaymentTransactionWrapper>();
        for (Payment__c p : Database.query(query)) {
            PaymentTransactionWrapper w = new PaymentTransactionWrapper();
            w.id = p.Id;
            w.name = p.Name;
            w.bookingId = p.Booking__c;
            w.bookingName = p.Booking__r != null ? p.Booking__r.Name : 'N/A';

            if (p.Booking__r != null && p.Booking__r.Customer__r != null) {
                String fn = p.Booking__r.Customer__r.First_Name__c != null ? p.Booking__r.Customer__r.First_Name__c + ' ' : '';
                w.customerName = fn + p.Booking__r.Customer__r.Last_Name__c;
            } else {
                w.customerName = 'N/A';
            }

            if (p.Booking__r != null && p.Booking__r.Car__r != null) {
                w.carName = p.Booking__r.Car__r.Brand__c + ' ' + p.Booking__r.Car__r.Car_Model__c;
            } else {
                w.carName = 'N/A';
            }

            w.amount = p.Amount__c;
            w.paymentDate = p.Payment_Date__c;
            w.paymentMethod = p.Payment_Method__c;
            w.paymentStatus = p.Payment_Status__c;
            w.transactionReference = p.Transaction_Reference__c;
            w.createdDate = p.CreatedDate;
            results.add(w);
        }
        return results;
    }

    /**
     * Record a new payment or refund.
     */
    @AuraEnabled
    public static Payment__c savePaymentRecord(Payment__c payment) {
        if (payment == null || payment.Amount__c == null) {
            throw new AuraHandledException('Payment amount is required.');
        }
        if (payment.Payment_Date__c == null) {
            payment.Payment_Date__c = Date.today();
        }
        if (String.isBlank(payment.Transaction_Reference__c)) {
            payment.Transaction_Reference__c = 'TXN-' + System.currentTimeMillis();
        }
        upsert payment;
        return payment;
    }

    /**
     * Mark a payment as Refunded.
     */
    @AuraEnabled
    public static Payment__c refundPayment(Id paymentId) {
        if (paymentId == null) {
            throw new AuraHandledException('Payment ID is required.');
        }
        Payment__c p = [SELECT Id, Payment_Status__c, Booking__c FROM Payment__c WHERE Id = :paymentId LIMIT 1];
        p.Payment_Status__c = 'Refunded';
        update p;
        return p;
    }
}
