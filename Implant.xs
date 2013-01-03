/* Copyright (C) 2004, 2008  Matthijs van Duin.  All rights reserved.
 * This program is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static MGVTBL subname_vtbl;

#ifndef PERL_MAGIC_ext
# define PERL_MAGIC_ext '~'
#endif

#ifndef SvMAGIC_set
#define SvMAGIC_set(sv, val) (SvMAGIC(sv) = (val))
#endif


MODULE = Sub::Implant  PACKAGE = Sub::Implant

PROTOTYPES: DISABLE

void
_subname(name, sub)
	char *name
	SV *sub
    PREINIT:
	CV *cv = NULL;
	GV *gv;
	HV *stash = CopSTASH(PL_curcop);
	char *s, *end = NULL, prev;
	MAGIC *mg;
        int utf8_flag;
    PPCODE:
	if (!SvROK(sub) && SvGMAGICAL(sub))
		mg_get(sub);
	if (SvROK(sub))
		cv = (CV *) SvRV(sub);
	else if (SvTYPE(sub) == SVt_PVGV)
		cv = GvCVu(sub);
	else if (!SvOK(sub))
		croak(PL_no_usym, "a subroutine");
	else if (PL_op->op_private & HINT_STRICT_REFS)
		croak("Can't use string (\"%.32s\") as %s ref while \"strict refs\" in use",
		      SvPV_nolen(sub), "a subroutine");
	else if ((gv = gv_fetchpv(SvPV_nolen(sub), FALSE, SVt_PVCV)))
		cv = GvCVu(gv);
	if (!cv)
		croak("Undefined subroutine %s", SvPV_nolen(sub));
	if (SvTYPE(cv) != SVt_PVCV && SvTYPE(cv) != SVt_PVFM)
		croak("Not a subroutine reference");

        utf8_flag = is_utf8_string((U8*) name, 0) ? SVf_UTF8 : 0;
        prev = '\0';
	for (s = name; *s++; ) {
		if (*s == ':' && prev == ':')
			end = ++s;
		else if (*s && prev == '\'')
			end = s;
                prev = *s;
	}
	s--;
	if (end) {
                stash = GvHV(gv_fetchpvn_flags(
                        name, end - name, utf8_flag | GV_ADD, SVt_PVHV
                ));
		name = end;
	}
	gv = (GV *) newSV(0);
        gv_init_pvn(gv, stash, name, s - name, utf8_flag | GV_ADDMULTI);
	mg = SvMAGIC(cv);
	while (mg && mg->mg_virtual != &subname_vtbl)
		mg = mg->mg_moremagic;
	if (!mg) {
		Newz(702, mg, 1, MAGIC);
		mg->mg_moremagic = SvMAGIC(cv);
		mg->mg_type = PERL_MAGIC_ext;
		mg->mg_virtual = &subname_vtbl;
		SvMAGIC_set(cv, mg);
	}
	if (mg->mg_flags & MGf_REFCOUNTED)
		SvREFCNT_dec(mg->mg_obj);
	mg->mg_flags |= MGf_REFCOUNTED;
	mg->mg_obj = (SV *) gv;
	SvRMAGICAL_on(cv);
	CvANON_off(cv);
#ifndef CvGV_set
	CvGV(cv) = gv;
#else
	CvGV_set(cv, gv);
#endif
	PUSHs(sub);


void
_get_subname(sub)
	SV *sub
    PREINIT:
	CV *cv = NULL;
	GV *gv;
        SV *name;
    PPCODE:
	if (!SvROK(sub) && SvGMAGICAL(sub))
		mg_get(sub);
	if (SvROK(sub))
		cv = (CV *) SvRV(sub);
	else if (SvTYPE(sub) == SVt_PVGV)
		cv = GvCVu(sub);
	else if (!SvOK(sub)) 
		croak(PL_no_usym, "a subroutine");
	else if (PL_op->op_private & HINT_STRICT_REFS)
		croak("Can't use string (\"%.32s\") as %s ref while \"strict refs\" in use",
		      SvPV_nolen(sub), "a subroutine");
	else if ((gv = gv_fetchpv(SvPV_nolen(sub), FALSE, SVt_PVCV)))
		cv = GvCVu(gv);
	if (!cv)
		croak("Undefined subroutine %s", SvPV_nolen(sub));
	if (SvTYPE(cv) != SVt_PVCV && SvTYPE(cv) != SVt_PVFM)
		croak("Not a subroutine reference");

        if (CvANON(cv))
                XSRETURN_EMPTY;
        gv = CvGV(cv);
        if (!gv)                      /* can this ever happen? */
                XSRETURN_EMPTY;
        name = sv_newmortal();
        gv_fullname(name, gv);
        PUSHs(name);
