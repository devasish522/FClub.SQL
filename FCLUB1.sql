use FClub
GO
CREATE TABLE ReturnProducts(
ReturnProductID		VARCHAR(50) PRIMARY KEY DEFAULT(NEWID()),
ReturnTransectionNo	VARCHAR(20) NOT NULL,
InvoiceDetailSaleID	VARCHAR(50) NOT NULL,
SKUCode				VARCHAR(20) NOT NULL,
ReturnAmount		DECIMAL(18,2) NOT NULL,
IsActive			BIT NOT NULL DEFAULT(1),
CreatedDate			SMALLDATETIME NOT NULL DEFAULT(GETDATE())
)
GO
DROP TABLE InvoiceDetails
go
CREATE TABLE InvoiceSaleDetails
(
InvoiceSaleDetailID		VARCHAR(50) PRIMARY KEY,
TransectionNo			VARCHAR(20) NOT NULL,
CustomerName			VARCHAR(50) NOT NULL,
PhoneNo					VARCHAR(15) NOT NULL, 
PaymentType				VARCHAR(20) NOT NULL,
CashAmount				DECIMAL(18,2),
UPIAmount				DECIMAL(18,2),
LoanAmount				DECIMAL(18,2),
AdditionalDiscount		DECIMAL(18,2),
IsGST					BIT NOT NULL,
IsReceipt				BIT NOT NULL,
ReturnTransectionNo		VARCHAR(20),
ReturnTransectionAmount DECIMAL(18,2),
IsActive				BIT NOT NULL DEFAULT(1),
CreatedDate				SMALLDATETIME NOT NULL DEFAULT(GETDATE())
)
GO
DROP TABLE SoldProducts
GO
CREATE TABLE SoldProducts
(
SoldProductID			VARCHAR(50) PRIMARY KEY DEFAULT(NEWID()),
InvoiceDetailSaleID		VARCHAR(50) NOT NULL,
SKUCode					VARCHAR(20) NOT NULL,
FinalAmount				DECIMAL(18,2) NOT NULL,
AdditionalDiscount		DECIMAL(18,2),
NoOfProducts			INT NOT NULL,
IsActive				BIT NOT NULL DEFAULT(1),
CreatedDate				SMALLDATETIME NOT NULL DEFAULT(GETDATE())
)
GO
ALTER PROC USP_SAVE_InvoiceDetailSale --'TFFDSg','Fg','1618',4,1200,NULL, null,300,1,NULL,NULL,'1231564312,FC0012452'      
(      
@TransectionNo		VARCHAR(20),      
@CustomerName		VARCHAR(50),      
@PhoneNo			VARCHAR(15),       
@PaymentType		VARCHAR(20),      
@CashAmount			DECIMAL(18,2),      
@UPIAmount			DECIMAL(18,2),      
@LoanAmount			DECIMAL(18,2),      
@AdditionalDiscount DECIMAL(18,2),      
@IsGST				BIT,
@IsReceipt			BIT,
@SKUCodes			VARCHAR(MAX),
@TotalItems			DECIMAL(18,2)
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
 INSERT INTO OutstandingAmounts(ContactPerson,ContactNumber,Date,Amount,OutstandingTypeID)  
 SELECT @CustomerName, @PhoneNo, GETDATE(), @LoanAmount, 2  
END

GO

CREATE PROC USP_SAVE_ReturnProducts --'HHS', '1231564312,FC0012452', 'TFFDS'
(
@ReturnTransectionNo	VARCHAR(20),
@ReturnTransectionAmount DECIMAL(18,2),
@SKUCodes				VARCHAR(MAX),
@TransectionNo			VARCHAR(20)
)
AS
BEGIN
INSERT INTO ReturnProducts(ReturnTransectionNo,InvoiceDetailSaleID,SKUCode,ReturnAmount)
SELECT @ReturnTransectionNo, IDS.InvoiceDetailSaleID, value, (SP.FinalAmount - SP.AdditionalDiscount) 
FROM string_split(@SKUCodes, ',') SS
INNER JOIN InvoiceSaleDetails	IDS WITH(NOLOCK) ON IDS.TransectionNo = @TransectionNo
INNER JOIN SoldProducts			SP	WITH(NOLOCK) ON SP.InvoiceDetailSaleID = IDS.InvoiceDetailSaleID AND SP.IsActive = 1 AND SP.SKUCode = SS.value
INNER JOIN Products				P	WITH(NOLOCK) ON P.SKUCode = SS.value
INNER JOIN ItemPrices			IPS	WITH(NOLOCK) ON IPS.ProductID = P.ProductID

UPDATE P SET P.IsActive = 1, P.NoOfProducts = P.NoOfProducts + 1 
FROM string_split(@SKUCodes, ',') SS
INNER JOIN Products				P	ON SS.value = P.SKUCode

UPDATE IDS SET IDS.ReturnTransectionNo = @ReturnTransectionNo, IDS.ReturnTransectionAmount = @ReturnTransectionAmount 
FROM string_split(@SKUCodes, ',') SS
INNER JOIN InvoiceSaleDetails	IDS WITH(NOLOCK) ON IDS.TransectionNo = @TransectionNo
INNER JOIN SoldProducts			SP	WITH(NOLOCK) ON SP.InvoiceDetailSaleID = IDS.InvoiceDetailSaleID AND SP.IsActive = 1 AND SP.SKUCode = SS.value
END
GO
CREATE PROC USP_GET_InvoiceSaleDetails
(
@Phone	VARCHAR(20),
@Date	DATE
)
AS
BEGIN
SELECT IDS.TransectionNo, IDS.CustomerName, IDS.PhoneNo, IDS.LoanAmount, IDS.AdditionalDiscount,
ISNULL(IDS.CashAmount, 0) + ISNULL(IDS.UPIAmount, 0) + ISNULL(IDS.LoanAmount, 0) + ISNULL(IDS.ReturnTransectionAmount, 0) AS BillAmount
FROM InvoiceSaleDetails IDS	WITH(NOLOCK)
WHERE IDS.PhoneNo = @Phone AND CAST(IDS.CreatedDate AS date) = @Date
END
go

Alter PROC USP_GET_ProductDetails --'FC10012'      
(      
@SKUCode VARCHAR(20)      
)      
AS      
BEGIN      
SELECT P.ProductName, S.Size, B.BrandName, S.SizeID, B.BrandID, IPS.MRP, IPS.FinalPrice AS MinPrice, IPS.DiscountAmount, P.SKUCode, P.ProductCode,      
IPS.ActualPrice,IPS.DiscountPercentage, P.NoOfProducts ,P.ProductID             
FROM Products P WITH(NOLOCK)      
JOIN ItemPrices IPS WITH(NOLOCK) ON P.ProductID = IPS.ProductID      
LEFT JOIN Sizes S WITH(NOLOCK) ON S.SizeID = IPS.SizeID      
LEFT JOIN Brands B WITH(NOLOCK) ON B.BrandID = IPS.BrandID      
WHERE P.SKUCode = @SKUCode AND P.IsActive = 1    
END