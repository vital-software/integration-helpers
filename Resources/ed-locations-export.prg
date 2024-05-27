/*********************** Start Change Control ********************************
Mod # 	Developer   	Date 		OPAS# 		Description
=============================================================================
000  Developer  05/25/2024   Sends ED locations every 15 minutes to Vital
                                                 
 
*******************************************************************************/
 
drop program vital_software_ed_locations : dba  go
create program vital_software_ed_locations : dba
 
prompt
	"Output to File/Printer/MINE" = "MINE"
 
with OUTDEV
 
 
declare  acct_alias_type  =  f8
 
set  acct_alias_type  =  uar_get_code_by ( "DISPLAYKEY" ,  319 ,  "FINNBR" )
 
declare  cnt_hits  =  i4
 
set  cnt_hits  =  0
 
free record patient_rec
 
record  patient_rec  (
 1  qual = i4
 1  patients [*]
 2  qual2 = i4
 2  patient_name = vc
 2  accnt_nbr = c12
 2  mrn = vc
 2  tracking_id = f8
 2  encntr_id = f8
 2  person_id = f8
 2  facility = vc
 2  loc [*]
 3  cur_unit = vc
 3  cur_loc = vc
 3  cur_bed = vc
 3  updt_dt_tm = vc
 3  reason = vc
  )
 

declare arrival_time_cd = f8 with public, constant (uar_get_code_by("DISPLAYKEY",72,"ARRIVALTIME"))
declare arrive_event_time = c40 with public, noconstant("                                        ")
declare discharge_dispo_cd = f8 with protect , constant ( uar_get_code_by ( "DISPLAYKEY" , 72 , "DISCHARGEDISPOSITION" ))
declare inerror_cd = f8 with public, constant(uar_get_code_by("MEANING",8,"INERROR") )
declare admitted_to_cd = f8 with protect , constant ( uar_get_code_by ( "DISPLAYKEY" , 72 , "ADMITTEDTO" ))
declare admit_order_cd = f8 with protect , constant ( uar_get_code_by ( "DISPLAYKEY" , 200 , "ADMITPATIENT" ))
 
set date1 = format(cnvtdatetime(curdate,curtime3),"mmddyyyy hh:mm:ss;;d")
set date2 = substring(1,8,date1)
set date3 = substring(10,2,date1)
set date4 = substring(13,2,date1)
declare filenm =vc
declare filename=vc
 
set filenm=concat("client_vitalsoftware_",date2,"_",date3,"_",date4,".csv")
set filename =concat("cust_proc:/vitalsoftware/",trim(filenm,3))
 
call echo(build2("looking for Patients" ))
 
 
select  into  "nl:"
 
name = p.name_full_formatted,
e.encntr_id,
t.tracking_id,
ea.alias,
t.checkin_dt_tm,
t.checkout_dt_tm,
pr.name_last
 
from ( tracking_checkin  t ),
( tracking_item  ti ),
 
( encounter  e ),
( encntr_alias  ea ),( encntr_alias  ea2 ),
( prsnl  pr ),
( person  p )
 
 plan ( t
Where (t.checkin_dt_tm between  cnvtdatetime (cnvtlookbehind("1,H",sysdate))
 and  cnvtdatetime (sysdate))
 and (t.tracking_group_cd+0 in (18801814.00, 18801936.00)))
 
 and ( ti
where (t.tracking_id= ti.tracking_id)
 and (ti.encntr_id > 0)
 and ( ti.active_ind = 1))
 
 and ( e
where (ti.encntr_id=e.encntr_id))
 and ( ea
where (ea.encntr_id=e.encntr_id) and (ea.encntr_alias_type_cd= acct_alias_type ))
 and ( ea2
where (ea2.encntr_id=e.encntr_id) and (ea2.encntr_alias_type_cd= 1079 ))
 and ( p
where (ti.person_id=p.person_id))
 and ( pr
where (t.primary_doc_id=pr.person_id))
 
order by  name,e.encntr_id
 

head report
 
 cnt_hits = 0
 
head e.encntr_id
 
call echo(build2("=================  t.tracking_id = ", t.tracking_id))
call echo(build2("=================  ti.tracking_id = ", ti.tracking_id))
call echo(build2("=================  p.name_full_formatted = ", p.name_full_formatted))
call echo(build2("=================  e.encntr_id = ", e.encntr_id ))
 
 
 cnt_hits =( cnt_hits + 1 ),
 
if ( ( mod ( cnt_hits ,  50 )= 1 ) )
  stat = alterlist ( patient_rec->patients , ( cnt_hits + 49 ))
endif
 
patient_rec->patients [cnt_hits]->patient_name = p.name_full_formatted,
patient_rec->patients [cnt_hits]->accnt_nbr = substring ( 1 ,  15 , ea.alias),
patient_rec->patients [cnt_hits]->mrn = substring ( 1 ,  15 , ea2.alias),
patient_rec->patients [cnt_hits]->tracking_id = t.tracking_id,
patient_rec->patients [cnt_hits]->encntr_id = e.encntr_id,
patient_rec->patients [cnt_hits]->person_id = e.person_id,
patient_rec->patients [cnt_hits]->facility = uar_get_code_description(e.loc_facility_cd)
 
foot report
 patient_rec->qual =cnt_hits,
 stat = alterlist ( patient_rec->patients , cnt_hits)
 
with  nocounter
 
;
 
 
select into "nl:"
uar_get_code_display(tl.loc_room_cd)
FROM ( DUMMYT  D  WITH  SEQ = VALUE ( patient_rec->qual )),
tracking_locator tl;,
 
 
 PLAN  D
 
join tl where tl.tracking_id = patient_rec->patients[d.seq].tracking_id
order by d.seq,tl.tracking_locator_id, tl.arrive_dt_tm,tl.depart_dt_tm
 
head d.seq
 
 cnt_hits = 0
head tl.tracking_locator_id
 
 cnt_hits =( cnt_hits + 1 ),
 
if ( ( mod ( cnt_hits ,  50 )= 1 ) )
  stat = alterlist ( patient_rec->patients[d.seq]->loc , ( cnt_hits + 49 ))
endif
 
patient_rec->patients[d.seq]->loc [cnt_hits].cur_unit = uar_get_code_description(tl.loc_nurse_unit_cd)
patient_rec->patients[d.seq]->loc [cnt_hits].cur_loc = uar_get_code_description(tl.loc_room_cd)
patient_rec->patients[d.seq]->loc [cnt_hits].cur_bed = uar_get_code_description(tl.loc_bed_cd)
patient_rec->patients[d.seq]->loc [cnt_hits].updt_dt_tm = format(tl.locator_create_date,'mm/dd/yyyy hh:mm:ss;;d')
patient_rec->patients[d.seq]->loc [cnt_hits].reason = tl.tracking_reason_comment
 
 
foot d.seq
 patient_rec->patients[d.seq]->qual2 =cnt_hits,
 stat = alterlist ( patient_rec->patients[d.seq]->loc , cnt_hits)
with nocounter
 
 
select  into  value ( filename)
mrn = substring(1,40, patient_rec->patients [d1.seq]->mrn)  ,
encounter = substring(1,40, patient_rec->patients [d1.seq]->accnt_nbr)  ,
facility = substring(1,40,trim(patient_rec->patients [d1.seq]->facility,3)),
department = substring(1,40,trim(patient_rec->patients [d1.seq]->loc[d2.seq].cur_unit,3)),
room = substring(1,30,trim(patient_rec->patients [d1.seq]->loc[d2.seq].cur_loc,3)),
bed = substring(1,30,trim(patient_rec->patients [d1.seq]->loc[d2.seq].cur_bed,3)),
datetimeupdated = substring(1,20,patient_rec->patients [d1.seq]->loc[d2.seq].updt_dt_tm) ,
tracking_id = patient_rec->patients [d1.seq]->tracking_id
 
from ( dummyt  d1  with  seq = value ( patient_rec->qual )),
( DUMMYT D2  WITH SEQ = 1)
PLAN (D1 where maxrec(d2, size(patient_rec->patients[d1.seq]->loc,5)))
join  D2
 
order by facility,encounter,datetimeupdated desc
with  FORMAT,FORMAT =  PCFORMAT,  SKIPREPORT= 1
 
record reply
(
   1 status_data[1]
     2 status = c1
)
 
set reply->status_data[1].status = "S"
;echo (reply->status_data[1].status)
 
 
#EXIT_SCRIPT
 
subroutine write_error_message(error_msg)
  select into $Outdev
  from dummyt d
  detail
    col 2, error_msg
  with nocounter, noheading, noformat
 
end
end
 go
 