'Trigger 1: The provided trigger calculates the total amount for a customer order by checking if a coupon code
is applied. If a valid coupon is provided (meeting the minimum purchase amount and not expired), the
corresponding discount is applied to the subtotal. Otherwise, the total amount remains equal to the subtotal.
This ensures that discounts are only granted under valid conditions.'
CREATE OR REPLACE TRIGGER trg_calculate_totalamount
BEFORE INSERT OR UPDATE ON CUSTOMER_ORDERS
FOR EACH ROW
DECLARE
v_minPurchase_amt NUMBER;
v_coupExpiry DATE;
v_coupDiscountAmt NUMBER;
BEGIN
-- Check if coupon code is provided
IF :NEW.coupon_code IS NOT NULL THEN
-- Fetch coupon details
SELECT minPurchase_amt, coupExpiry, coupDiscountAmt
INTO v_minPurchase_amt, v_coupExpiry, v_coupDiscountAmt
FROM COUPONS
WHERE coupon_code = :NEW.coupon_code;
-- Validate the coupon
IF :NEW.subtotal >= v_minPurchase_amt AND SYSDATE <=
v_coupExpiry THEN
-- Valid coupon: apply discount
:NEW.totalamount := :NEW.subtotal - v_coupDiscountAmt;
ELSE
-- Invalid coupon: no discount applied
:NEW.totalamount := :NEW.subtotal;
END IF;
ELSE
-- No coupon provided: totalamount = subtotal
:NEW.totalamount := :NEW.subtotal;
END IF;
END;
/
'Trigger 2: This trigger automatically updates the inv_stock_status field in the INVENTORY_DETAILS table
based on the quantity on hand (inv_qoh) relative to the reorder level (inv_reorder_level). It sets the status to
"Low" if stock is at or below the reorder level, "Decent" if its up to twice the reorder level, and "High"
otherwise.'
CREATE OR REPLACE TRIGGER trg_update_stock_status
BEFORE INSERT OR UPDATE ON INVENTORY_DETAILS
FOR EACH ROW
BEGIN
-- Evaluate the stock status based on inv_qoh and
inv_reorder_level
IF :NEW.inv_qoh <= :NEW.inv_reorder_level THEN
:NEW.inv_stock_status := 'Low';
ELSIF :NEW.inv_qoh <= 2 * :NEW.inv_reorder_level THEN
:NEW.inv_stock_status := 'Decent';
ELSE
:NEW.inv_stock_status := 'High';
END IF;
END;
/
'Trigger 3: This trigger ensures efficient inventory management by validating stock availability before
processing new shipments. When a shipment is recorded, it checks if sufficient stock exists for the raw
material. If stock is unavailable, it prevents the shipment and raises an error, avoiding overselling or
overbooking issues. Additionally, it immediately reduces the stock count upon successful validation,
maintaining real-time inventory accuracy and enabling better supply chain decisions.
CREATE OR REPLACE TRIGGER trg_validate_stock_on_shipment'
BEFORE INSERT ON SHIPMENT_DETAILS
FOR EACH ROW
DECLARE
available_quantity NUMBER;
BEGIN
-- Get the current stock for the raw material
SELECT quantity
INTO available_quantity
FROM RAW_MATERIALS
WHERE material_Id = :NEW.Material_Id;
-- Validate stock availability
IF available_quantity <= 0 THEN
RAISE_APPLICATION_ERROR(-20005, 'Insufficient stock for the
material.');
END IF;
-- Reserve stock (reduce immediately to avoid overbooking)
UPDATE RAW_MATERIALS
SET quantity = quantity - 1
WHERE material_Id = :NEW.Material_Id;
END;
/
'Procedure: The ProcessPurchaseOrder function automates the handling of raw material purchase orders by
validating the materials existence in the RAW_MATERIALS table, inserting the purchase order details into
the PURCHASE_ORDER table, and updating the inventory to reflect the new stock. It also includes error
handling to address issues like missing materials or unexpected failures, ensuring that changes are rolled back
in case of errors.'
CREATE OR REPLACE PROCEDURE ProcessPurchaseOrder(
p_po_no IN PURCHASE_ORDER.PONo%TYPE,
p_material_id IN RAW_MATERIALS.material_Id%TYPE,
p_purchase_qty IN PURCHASE_ORDER.PurcQty%TYPE,
p_po_date IN PURCHASE_ORDER.PODate%TYPE
) AS
v_current_quantity RAW_MATERIALS.quantity%TYPE;
v_new_quantity RAW_MATERIALS.quantity%TYPE;
BEGIN
-- Validate if the material exists
SELECT quantity INTO v_current_quantity
FROM RAW_MATERIALS
WHERE material_Id = p_material_id;
-- Calculate the new quantity after purchase
v_new_quantity := v_current_quantity + p_purchase_qty;
-- Insert the purchase order details
INSERT INTO PURCHASE_ORDER (
PONo, PODate, PurcQty, Material_Id
) VALUES (
p_po_no, p_po_date, p_purchase_qty, p_material_id
);
-- Update the quantity in RAW_MATERIALS
UPDATE RAW_MATERIALS
SET quantity = v_new_quantity
WHERE material_Id = p_material_id;
-- Commit the transaction
COMMIT;
DBMS_OUTPUT.PUT_LINE('Purchase Order Processed Successfully: ' ||
p_po_no);
DBMS_OUTPUT.PUT_LINE('Material ID: ' || p_material_id || ' Updated
Quantity: ' || v_new_quantity);
EXCEPTION
WHEN NO_DATA_FOUND THEN
RAISE_APPLICATION_ERROR(-20002, 'Material ID not found in
RAW_MATERIALS table.');
WHEN OTHERS THEN
ROLLBACK;
RAISE_APPLICATION_ERROR(-20003, 'An unexpected error occurred: '
|| SQLERRM);
END ProcessPurchaseOrder;
/
How to execute:
BEGIN
ProcessPurchaseOrder('PO0000000013', 'RM0000000001', 500, SYSDATE);
END;
/