#----------------------------------------------------------------------------#

# Purpose:     Annotate orders with product ids, etc.
# Author:      CM
# Date:        2016
# Language:    Python (.py)


#----------------------------------------------------------------------------#

#----------------------------------------------------------------------------#
#                               Control Section                              #
#----------------------------------------------------------------------------#

# control parameters
#-------------------------------------------------#

# paths
init_path=sys.argv[1]
input_path=sys.argv[2]
raw_input_path=sys.argv[3]
annotated_input_path=sys.argv[4]
execution_id=sys.argv[5]
output_path=sys.argv[6]
log_path=sys.argv[7]
archive_path_input=sys.argv[8]
archive_path_output=sys.argv[9]
vb_input_path=sys.argv[10]


# dependencies
#-------------------------------------------------#
import sys
sys.path.append(init_path)

from python_init import *

# parameters
#-------------------------------------------------#

input_path=input_path+"/*"+execution_id+".xlsm"

#----------------------------------------------------------------------------#
#                                    Code                                    #
#----------------------------------------------------------------------------#

start_time = time.time()

# read in xlsx 
#----------------------------------------------------------------------------#
output_file_list = glob.glob(input_path)

order_name=[]
order_product_code_1=[]
order_product_code_2=[]
order_product_code_3=[]
order_price_1=[]
order_price_2=[]
order_price_3=[]
order_id=[]
email=[]

for x in range(0, len(output_file_list)):

    # read in 
    temp=load_workbook(output_file_list[x])
    temp_ws=temp['MASTER RECORD']

    # obtain relevant values
    temp_order_name=[temp_ws.cell(row=i,column=9).value for i in range(1,temp_ws.max_row)]
    temp_order_product_code_1=[temp_ws.cell(row=i,column=3).value for i in range(1,temp_ws.max_row)]
    temp_order_product_code_2=[temp_ws.cell(row=i,column=5).value for i in range(1,temp_ws.max_row)]
    temp_order_product_code_3=[temp_ws.cell(row=i,column=7).value for i in range(1,temp_ws.max_row)]
    temp_order_price_1=[temp_ws.cell(row=i,column=4).value for i in range(1,temp_ws.max_row)]
    temp_order_price_2=[temp_ws.cell(row=i,column=6).value for i in range(1,temp_ws.max_row)]
    temp_order_price_3=[temp_ws.cell(row=i,column=8).value for i in range(1,temp_ws.max_row)]

    temp_order_id=[temp_ws.cell(row=i,column=10).value for i in range(1,temp_ws.max_row)]

    temp_email=[temp_ws.cell(row=i,column=13).value for i in range(1,temp_ws.max_row)]

    # append
    order_name.append(temp_order_name)
    order_product_code_1.append(temp_order_product_code_1)
    order_product_code_2.append(temp_order_product_code_2)
    order_product_code_3.append(temp_order_product_code_3)
    order_price_1.append(temp_order_price_1)
    order_price_2.append(temp_order_price_2)
    order_price_3.append(temp_order_price_3)

    order_id.append(temp_order_id)
    
    email.append(temp_email)

## create final dt
order_dt=pd.DataFrame({'order_name': order_name[0][1:],
     'order_product_code_1': order_product_code_1[0][1:],
     'order_product_code_2': order_product_code_2[0][1:],
     'order_product_code_3': order_product_code_3[0][1:],
     'order_price_1': order_price_1[0][1:],
     'order_price_2': order_price_2[0][1:],
     'order_price_3': order_price_3[0][1:],
     'order_id': order_id[0][1:], 
     'email': email[0][1:]
    })


# loop over
#----------------------------------------------------------------------------#
file_list_final = order_dt['order_name']
file_list_final = file_list_final.unique()
file_count=len(file_list_final)

for x in range(0, len(file_list_final)):


    file_name_mod=annotated_input_path + "/" + file_list_final[x] + '.pdf'
    file_name_raw=raw_input_path + "/" + file_list_final[x] + '.pdf'

    print file_name_mod 

    # obtain order_dt_subset
    #----------------------------------------------------------------------------#
    order_dt_subset=order_dt.ix[order_dt['order_name']==file_list_final[x]]
    order_dt_subset.reset_index(inplace=True, drop=True)
    

    # parse PDF 
    #----------------------------------------------------------------------------#
    # read existing PDF
    existing_pdf             = PdfFileReader(file(file_name_mod, "rb"))
    existing_pdf_page_number = existing_pdf.getNumPages() 

    # parse
    position_class   = pdfPositionHandling()
    position         = position_class.parsepdf(file_name_mod, 0, existing_pdf_page_number)
    position_sort    = position.sort_values(['page', 'pos_y'],  ascending=[1, 0])
    position_sort.reset_index(inplace=True, drop=True)
    
    # read existing PDF - RAW
    existing_pdf_raw  = PdfFileReader(file(file_name_raw, "rb"))

    
    # new PDF 
    #----------------------------------------------------------------------------#
    can_list    = []
    packet_list = []
    pdf_list    = []


    for i in range(0,existing_pdf_page_number):
        packet_temp = StringIO.StringIO()
        can_temp    = canvas.Canvas(packet_temp)
        packet_list.append(packet_temp)
        can_list.append(can_temp)

    # iterate through order_dt_subset
    #----------------------------------------------------------------------------#

    for y in range(0, len(order_dt_subset)):

        # obtain data
        id_1=order_dt_subset['order_product_code_1'][y]
        id_2=order_dt_subset['order_product_code_2'][y]
        id_3=order_dt_subset['order_product_code_3'][y]

        price_1=order_dt_subset['order_price_1'][y]
        price_2=order_dt_subset['order_price_2'][y]
        price_3=order_dt_subset['order_price_3'][y]

        text_1 = str(id_1) + " / " + str(price_1)
        text_1=  re.sub("None|nan|#N/A", "", text_1)
        text_1=  re.sub("^ / $", "", text_1)
        text_2 = str(id_2) + " / " + str(price_2)
        text_2=  re.sub("None|nan|#N/A", "", text_2)
        text_2=  re.sub("^ / $", "", text_2)
        text_3 = str(id_3) + " / " + str(price_3)
        text_3=  re.sub("None|nan|#N/A", "", text_3)
        text_3=  re.sub("^ / $", "", text_3)

        order_id=order_dt_subset['order_id'][y]

        # identify the correct position 
        position_prod_subset=position_sort.copy()
        position_prod_subset.ix[position_prod_subset["text"].str.contains("#order-item: " + str(order_id) + "([^0-9]|$)"), "min"]=0
        position_prod_subset.ix[position_prod_subset["text"].str.contains("#order-item: " + str(order_id+1) + "([^0-9]|$)"), "min"]=1
        position_prod_subset.fillna(method="ffill", inplace=True)
        position_prod_subset=position_prod_subset.ix[position_prod_subset["min"]==0]


        min_index=position_prod_subset.index.min()
        max_index=position_prod_subset.index.max()
        id_line = position_prod_subset[position_prod_subset["text"].str.contains("(Stck( |$))|(Stk( |$))|(St( |$))")].index
        
        if (id_line.shape[0]>0):
            position_line=np.array(id_line)[0]
            x1    = position_sort.ix[(position_line)]["pos_x"]+60
            y1    = position_sort.ix[(position_line)]["pos_y"]+1
            y_1   = y1-10
            y_2   = y1-20

        else:
            position_line=min_index
            x1    = max(position_prod_subset["pos_x"])+10
            y1    = position_sort.ix[(min_index)]["pos_y"] - 20
            y_1   = y1-10
            y_2   = y1-20

        page_num = position_sort.ix[(position_line)]["page"]   


        # print
        #----------------------------------------------------------------------------#

        # iterate & draw line/add text
        can_page = can_list[page_num]
        can_page.setFont('Helvetica', 10)
        can_page.setFillColor("blue")
        can_page.drawString(x1, y1, text_1)
        can_page.drawString(x1, y_1, text_2)
        can_page.drawString(x1, y_2, text_3)      
          
    # merge with background PDF
    #----------------------------------------------------------------------------#
    for i in range(0,existing_pdf_page_number):
        can_list[i].save()
        packet_list[i].seek(0)
        pdf_list.append(PdfFileReader(packet_list[i]))

    output = PdfFileWriter()

    for i in range(0,existing_pdf_page_number):
        page = existing_pdf_raw.getPage(i)
        if pdf_list[i].getNumPages()>0:
            page.mergePage(pdf_list[i] .getPage(0))
        output.addPage(page)

    # save 
    outputStream = file(output_path + "/"+  file_list_final[x] + '.pdf', "wb")
    output.write(outputStream)
    outputStream.close()

# save email list
#----------------------------------------------------------------------------#
email_dt=order_dt[['email','order_name']]
email_dt=email_dt.drop_duplicates()
email_dt['order_name_mod'] = [re.sub("^[0-9]*_", "",x) for x in  email_dt['order_name']]
email_dt['order_name_mod'] = [re.sub("_", " ",x) for x in  email_dt['order_name_mod']]

# save
email_dt.to_csv(output_path + "/" + "email_list_" +execution_id + ".csv", encoding="utf8")


# move files to archive
#----------------------------------------------------------------------------#


## vb input
input_file_list = glob.glob(vb_input_path +"/*"+execution_id+"*")

for x in range(0, len(input_file_list)):

    archive_file_path=archive_path_input
    shutil.move(input_file_list[x], archive_file_path)


## vb output 
output_file_list = glob.glob(input_path)

for x in range(0, len(output_file_list)):

    archive_file_path=archive_path_output
    shutil.move(output_file_list[x], archive_file_path)


# status & log file
#----------------------------------------------------------------------------#

end_time = time.time()

print "Number of PDFs: " + str(file_count)
print "Runtime (minutes):" + str((end_time - start_time))

orig_stdout = sys.stdout
log_file  = open(log_path+'/log_order_output'+'.txt','a+')
sys.stdout = log_file

print "\n\n###############" 
print "Execution ID: " + execution_id
print "Date: " + str(datetime.date.today())

print "\n\nNumber of PDFs: " + str(file_count)
print "Runtime (minutes):" + str(end_time - start_time) 

sys.stdout = orig_stdout
log_file.close()


#----------------------------------------------------------------------------#
#                                    End                                     #
#----------------------------------------------------------------------------#

