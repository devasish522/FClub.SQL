CREATE TABLE PaymentTypes
(
PaymentTypeID	VARCHAR(15) PRIMARY KEY,
PaymentType		VARCHAR(15) NOT NULL
)
GO

INSERT INTO PaymentTypes(PaymentTypeID, PaymentType) VALUES 
('CASH', 'Cash'),
('UPI', 'UPI'),
('CASH_UPI', 'Cash & UPI'),
('LOAN', 'Loan'),
('LOAN_UPI', 'Loan & UPI'),
('LOAN_CASH', 'Loan & Cash')

GO

--drop table LoanPaymentDetails
--go
--CREATE TABLE LoanPaymentDetails
--(
--LoanPaymentDetailID INT IDENTITY(1,1) PRIMARY KEY,
--OutstandingAmountID	INT NOT NULL,
--Amount				DECIMAL(18,2) NOT NULL,
--PaymentTypeID		VARCHAR(15) NOT NULL,
--IsActive			BIT NOT NULL DEFAULT(1),
--CreatedDate			SMALLDATETIME NOT NULL DEFAULT(GETDATE())
--)

GO

ALTER TABLE OutstandingPayableInvoices 
ADD PaymentTypeID VARCHAR(15)
GO

CREATE PROC USP_GET_DayWiseSaleDetails    
(    
@Date DATE    
)    
AS    
BEGIN    
SELECT SUM(ISNULL(ISD.CashAmount, 0)) AS Cash, SUM(ISNULL(ISD.LoanAmount, 0)) AS Loan, SUM(ISNULL(ISD.UPIAmount, 0)) AS UPI, ExpenseAmount = 0  
FROM InvoiceSaleDetails ISD WITH(NOLOCK)    
WHERE CAST(ISD.CreatedDate AS DATE) = CAST(@Date AS DATE)    
GROUP BY ISD.PaymentType, ISD.CashAmount, ISD.LoanAmount, ISD.UPIAmount    
    
UNION ALL    
    
SELECT CASE WHEN LPD.PaymentTypeID = 'CASH' THEN SUM(ISNULL(LPD.PaidAmount, 0)) END AS Cash, 0 AS Loan,     
CASE WHEN LPD.PaymentTypeID = 'UPI' THEN SUM(ISNULL(LPD.PaidAmount, 0)) END AS UPI, ExpenseAmount = 0    
FROM OutstandingPayableInvoices LPD WITH(NOLOCK)    
WHERE CAST(LPD.CreatedDate AS DATE) = CAST(@Date AS DATE) AND LPD.IsActive = 1  
GROUP BY LPD.PaymentTypeID, LPD.PaidAmount    
  
UNION ALL  
  
SELECT Cash = 0, Loan = 0, UPI = 0,   ExpenseAmount = SUM(ISNULL(SE.Amount, 0))  
FROM ShopExpenses  SE WITH(NOLOCK)   
JOIN ShopExpensesType ET WITH(NOLOCK) ON SE.ShopExpensesTypeID = ET.ShopExpensesTypeID  
WHERE SE.IsActive = 1 AND CAST(@Date AS DATE) = CAST(SE.ExpensesDate AS DATE) AND ET.ShopExpensesTypeID != 20  
END
go

ALTER PROC USP_SAVE_InvoiceDetailSale --'TFFDSg','Fg','1618',4,1200,NULL, null,300,1,NULL,NULL,'1231564312,FC0012452'        
(        
@TransectionNo  VARCHAR(20),        
@CustomerName  VARCHAR(50),        
@PhoneNo   VARCHAR(15),         
@PaymentType  VARCHAR(20),        
@CashAmount   DECIMAL(18,2),        
@UPIAmount   DECIMAL(18,2),        
@LoanAmount   DECIMAL(18,2),        
@AdditionalDiscount DECIMAL(18,2),        
@IsGST    BIT,  
@IsReceipt   BIT,  
@SKUCodes   VARCHAR(MAX),  
@TotalItems   DECIMAL(18,2)  
)        
AS        
BEGIN        
DECLARE @InvoiceDetailSaleID varchar(50) = CONVERT(VARCHAR(50), NEWID());        
INSERT INTO InvoiceSaleDetails(InvoiceSaleDetailID, TransectionNo, CustomerName, PhoneNo, PaymentType, CashAmount, UPIAmount, LoanAmount,       
AdditionalDiscount, IsGST, IsReceipt)        
VALUES(@InvoiceDetailSaleID, @TransectionNo, @CustomerName, @PhoneNo, @PaymentType, @CashAmount, @UPIAmount, @LoanAmount, @AdditionalDiscount,        
@IsGST, @IsReceipt)        
        
INSERT INTO SoldProducts(InvoiceDetailSaleID, SKUCode, FinalAmount, NoOfProducts, AdditionalDiscount)        
SELECT @InvoiceDetailSaleID, SUBSTRING(SS.value, 0, PATINDEX('%~%', SS.value)), (IPS.MRP - ROUND(IPS.DiscountAmount, 0) - Round((@AdditionalDiscount / @TotalItems), 2)),  
CAST(SUBSTRING(SS.value, PATINDEX('%~%', SS.value) + 1, len(SS.value)) AS INT), Round((@AdditionalDiscount / @TotalItems), 2)  
FROM string_split(@SKUCodes, ',') SS  
JOIN Products P WITH(NOLOCK) ON SUBSTRING(SS.value, 0, PATINDEX('%~%', SS.value)) = P.SKUCode        
JOIN ItemPrices IPS WITH(NOLOCK) ON P.ProductID = IPS.ProductID        
    
UPDATE P SET P.IsActive = CASE WHEN P.NoOfProducts - CAST(SUBSTRING(SS.value, PATINDEX('%~%', SS.value) + 1, len(SS.value)) AS INT) <= 0 THEN 0 ELSE 1 END,   
P.NoOfProducts = P.NoOfProducts - CAST(SUBSTRING(SS.value, PATINDEX('%~%', SS.value) + 1, len(SS.value)) AS INT)  
FROM string_split(@SKUCodes, ',') SS    
INNER JOIN Products P ON SUBSTRING(SS.value, 0, PATINDEX('%~%', SS.value)) = P.SKUCode    
    
IF(@LoanAmount > 0)    
 INSERT INTO OutstandingAmounts(ContactPerson,ContactNumber,Date,Amount,OutstandingTypeID, PaidAmount)    
 SELECT @CustomerName, @PhoneNo, GETDATE(), (ISNULL(@CashAmount, 0) + ISNULL(@UPIAmount, 0) + (ISNULL(@LoanAmount, 0))), 2, (ISNULL(@CashAmount, 0) + ISNULL(@UPIAmount, 0))
END  

GO

CREATE PROC USP_GET_ProductWiseSales --'2022-10-01', '2022-10-31'  
(  
@StartDate DATE,  
@EndDate DATE  
)  
AS  
BEGIN  
SELECT COUNT(P.ItemID) AS ItemWiseTotal, I.ItemName, I.ItemCode   
FROM Items   I  WITH(NOLOCK)  
JOIN Products  P  WITH(NOLOCK) ON I.ItemID = P.ItemID  
JOIN SoldProducts SP WITH(NOLOCK) ON P.SKUCode = SP.SKUCode  
WHERE SP.IsActive = 1 AND CAST(SP.CreatedDate AS DATE) BETWEEN @StartDate AND @EndDate  
GROUP BY P.ItemID, I.ItemName, I.ItemCode  
END