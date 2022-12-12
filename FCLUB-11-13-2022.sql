use FClub
go

alter table InvoiceSaleDetails
add TransectionDate date

go
update u set u.TransectionDate = u.createddate from InvoiceSaleDetails u

go

SP_RENAME 'SoldProducts.InvoiceDetailSaleID', 'InvoiceSaleDetailID', 'COLUMN'

GO

CREATE VIEW SalesInformation
AS
SELECT SP.SoldProductID, SP.SKUCode, SP.FinalAmount, SP.AdditionalDiscount AS AdditionalDiscountForProduct , SP.NoOfProducts, 
ISD.InvoiceSaleDetailID, ISD.TransectionNo, ISD.CustomerName, ISD.PhoneNo, ISD.PaymentType, ISD.CashAmount, ISD.UPIAmount, ISD.LoanAmount,
ISD.AdditionalDiscount, ISD.IsGST, ISD.IsReceipt, ISD.ReturnTransectionNo, ISD.ReturnTransectionAmount, ISD.TransectionDate
FROM		InvoiceSaleDetails	ISD WITH(NOLOCK)
INNER JOIN	SoldProducts		SP  WITH(NOLOCK) ON SP.InvoiceSaleDetailID = ISD.InvoiceSaleDetailID
WHERE SP.IsActive = 1 AND ISD.IsActive = 1

GO

ALTER PROC USP_SAVE_ReturnProducts --'HHS', '1231564312,FC0012452', 'TFFDS'  
(  
@ReturnTransectionNo VARCHAR(20),  
@ReturnTransectionAmount DECIMAL(18,2),  
@SKUCodes    VARCHAR(MAX),  
@TransectionNo   VARCHAR(20)  
)  
AS  
BEGIN  
INSERT INTO ReturnProducts(ReturnTransectionNo,InvoiceDetailSaleID,SKUCode,ReturnAmount)  
SELECT @ReturnTransectionNo, SI.InvoiceSaleDetailID, value, (SI.FinalAmount - SI.AdditionalDiscountForProduct)   
FROM string_split(@SKUCodes, ',') SS
INNER JOIN SalesInformation		SI WITH(NOLOCK) ON SI.TransectionNo = @TransectionNo AND SI.SKUCode = SS.value
INNER JOIN Products    P WITH(NOLOCK) ON P.SKUCode = SS.value  
INNER JOIN ItemPrices   IPS WITH(NOLOCK) ON IPS.ProductID = P.ProductID  

UPDATE P SET P.IsActive = 1, P.NoOfProducts = P.NoOfProducts + 1   
FROM string_split(@SKUCodes, ',') SS  
INNER JOIN Products    P ON SS.value = P.SKUCode  
  
UPDATE SI SET SI.ReturnTransectionNo = @ReturnTransectionNo, SI.ReturnTransectionAmount = @ReturnTransectionAmount
FROM string_split(@SKUCodes, ',') SS  
INNER JOIN SalesInformation	SI WITH(NOLOCK) ON SI.TransectionNo = @TransectionNo AND SI.SKUCode = SS.value

UPDATE SI SET SI.NoOfProducts = SI.NoOfProducts - 1, SI.IsActive = CASE WHEN SI.NoOfProducts > 1 THEN 0 ELSE 1 END
FROM string_split(@SKUCodes, ',') SS  
INNER JOIN InvoiceSaleDetails	ISD	WITH(NOLOCK) ON  ISD.TransectionNo = @TransectionNo
INNER JOIN SoldProducts			SI	WITH(NOLOCK) ON  SI.SKUCode = SS.value
END
GO

CREATE PROC USP_GET_ReturnProductBySKUCode    
(    
@SKUCode VARCHAR(20)    
)    
AS    
BEGIN    
SELECT SI.TransectionNo, SI.CustomerName, SI.PhoneNo, CONVERT(varchar, SI.TransectionDate, 101) AS TransectionDate, SI.PaymentType, SI.CashAmount, SI.UPIAmount, SI.LoanAmount  
FROM SalesInformation SI WITH(NOLOCK)    
WHERE SI.SKUCode = @SKUCode    
END