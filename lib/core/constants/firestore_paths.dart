/// Centralized Firestore collection and document path definitions matching Master Specification.
class FirestorePaths {
  FirestorePaths._();

  // Root collections
  static const String usersCollection = 'users';
  static const String organizationsCollection = 'organizations';

  // User paths
  static String userDoc(String uid) => '$usersCollection/$uid';

  // Organization-scoped collections
  static String organizationDoc(String orgId) =>
      '$organizationsCollection/$orgId';

  // Employees
  static String employeesCollection(String orgId) =>
      '${organizationDoc(orgId)}/employees';
  static String employeeDoc(String orgId, String employeeId) =>
      '${employeesCollection(orgId)}/$employeeId';

  // Products
  static String productsCollection(String orgId) =>
      '${organizationDoc(orgId)}/products';
  static String productDoc(String orgId, String productId) =>
      '${productsCollection(orgId)}/$productId';

  // Product BOMs
  static String productBomsCollection(String orgId, String productId) =>
      '${productDoc(orgId, productId)}/boms';
  static String productBomDoc(String orgId, String productId, String bomId) =>
      '${productBomsCollection(orgId, productId)}/$bomId';
  static String productBomFilesCollection(String orgId, String productId) =>
      '${productDoc(orgId, productId)}/bomFiles';
  static String productBomFileDoc(String orgId, String productId, String fileId) =>
      '${productBomFilesCollection(orgId, productId)}/$fileId';

  // Process Templates
  static String processTemplatesCollection(String orgId) =>
      '${organizationDoc(orgId)}/processTemplates';
  static String processTemplateDoc(String orgId, String templateId) =>
      '${processTemplatesCollection(orgId)}/$templateId';
  static String processTemplateStepsCollection(String orgId, String templateId) =>
      '${processTemplateDoc(orgId, templateId)}/steps';
  static String processTemplateStepDoc(String orgId, String templateId, String stepId) =>
      '${processTemplateStepsCollection(orgId, templateId)}/$stepId';

  // Production Orders
  static String productionOrdersCollection(String orgId) =>
      '${organizationDoc(orgId)}/productionOrders';
  static String productionOrderDoc(String orgId, String orderId) =>
      '${productionOrdersCollection(orgId)}/$orderId';

  // Production Order Processes (Subcollection)
  static String orderProcessesCollection(String orgId, String orderId) =>
      '${productionOrderDoc(orgId, orderId)}/processes';
  static String orderProcessDoc(String orgId, String orderId, String processId) =>
      '${orderProcessesCollection(orgId, orderId)}/$processId';

  // Process Incremental Updates (Subcollection)
  static String processUpdatesCollection(String orgId, String orderId, String processId) =>
      '${orderProcessDoc(orgId, orderId, processId)}/updates';
  static String processUpdateDoc(String orgId, String orderId, String processId, String updateId) =>
      '${processUpdatesCollection(orgId, orderId, processId)}/$updateId';

  // Materials & Master Inventory
  static String materialsCollection(String orgId) =>
      '${organizationDoc(orgId)}/materials';
  static String materialDoc(String orgId, String materialId) =>
      '${materialsCollection(orgId)}/$materialId';

  // Inventory Balances (materialLocationId = ${materialId}_MAIN)
  static String inventoryBalancesCollection(String orgId) =>
      '${organizationDoc(orgId)}/inventoryBalances';
  static String inventoryBalanceDoc(String orgId, String materialLocationId) =>
      '${inventoryBalancesCollection(orgId)}/$materialLocationId';

  // Authoritative Inventory Transaction Ledger
  static String inventoryTransactionsCollection(String orgId) =>
      '${organizationDoc(orgId)}/inventoryTransactions';
  static String inventoryTransactionDoc(String orgId, String transactionId) =>
      '${inventoryTransactionsCollection(orgId)}/$transactionId';

  // Queries & Tickets
  static String processQueriesCollection(String orgId) =>
      '${organizationDoc(orgId)}/processQueries';
  static String processQueryDoc(String orgId, String queryId) =>
      '${processQueriesCollection(orgId)}/$queryId';
  static String queryResponsesCollection(String orgId, String queryId) =>
      '${processQueryDoc(orgId, queryId)}/responses';
  static String queryResponseDoc(String orgId, String queryId, String responseId) =>
      '${queryResponsesCollection(orgId, queryId)}/$responseId';

  // Notifications
  static String notificationsCollection(String orgId) =>
      '${organizationDoc(orgId)}/notifications';
  static String notificationDoc(String orgId, String notificationId) =>
      '${notificationsCollection(orgId)}/$notificationId';

  // Audit Logs
  static String auditLogsCollection(String orgId) =>
      '${organizationDoc(orgId)}/auditLogs';
  static String auditLogDoc(String orgId, String logId) =>
      '${auditLogsCollection(orgId)}/$logId';

  // Billing & GST Invoices (Admin Only)
  static const String invoices = 'invoices';
  static const String invoiceCounters = 'invoiceCounters';
  static const String customers = 'customers';
  static const String billingConfig = 'billingConfig';

  static String invoicesCollection(String orgId) =>
      '${organizationDoc(orgId)}/invoices';
  static String invoiceDoc(String orgId, String invoiceId) =>
      '${invoicesCollection(orgId)}/$invoiceId';
  static String invoicePaymentsCollection(String orgId, String invoiceId) =>
      '${invoiceDoc(orgId, invoiceId)}/payments';
  static String invoicePaymentDoc(String orgId, String invoiceId, String paymentId) =>
      '${invoicePaymentsCollection(orgId, invoiceId)}/$paymentId';
  static String billingCustomersCollection(String orgId) =>
      '${organizationDoc(orgId)}/customers';
  static String billingCustomerDoc(String orgId, String customerId) =>
      '${billingCustomersCollection(orgId)}/$customerId';
  static String billingConfigDoc(String orgId) =>
      '${organizationDoc(orgId)}/billingConfig/main';
  static String invoiceCountersCollection(String orgId) =>
      '${organizationDoc(orgId)}/invoiceCounters';
  static String invoiceCounterDoc(String orgId, String financialYear) =>
      '${invoiceCountersCollection(orgId)}/$financialYear';

  // Jobwork Purchase Orders (M&G Stage 4)
  static String jobworkPosCollection(String orgId) =>
      '${organizationDoc(orgId)}/jobworkPOs';
  static String jobworkPoDoc(String orgId, String poId) =>
      '${jobworkPosCollection(orgId)}/$poId';

  // Backward compatibility aliases
  static String processTasksCollection(String orgId) =>
      '${organizationDoc(orgId)}/process_tasks';
  static String statusUpdatesCollection(String orgId) =>
      '${organizationDoc(orgId)}/status_updates';
}
