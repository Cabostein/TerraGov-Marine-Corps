/obj/structure/closet
	name = "closet"
	desc = "It's a basic storage unit."
	icon = 'icons/obj/closet.dmi'
	icon_state = "closed"
	density = 1
	flags_atom = FPRINT
	var/icon_closed = "closed"
	var/icon_opened = "open"
	var/opened = 0
	var/welded = 0
	var/wall_mounted = 0 //never solid (You can always pass over it)
	var/health = 100
	var/lastbang
	var/storage_capacity = 30 //This is so that someone can't pack hundreds of items in a locker/crate
							  //then open it in a populated area to crash clients.
	var/open_sound = 'sound/machines/click.ogg'
	var/close_sound = 'sound/machines/click.ogg'

	var/store_items = TRUE
	var/store_mobs = TRUE

	anchored = 1 //Yep

	var/const/mob_size = 15

/obj/structure/closet/initialize()
	..()
	spawn(1)
		if(!opened)		// if closed, any item at the crate's loc is put in the contents
			for(var/obj/item/I in src.loc)
				if(I.density || I.anchored || I == src) continue
				I.loc = src

/obj/structure/closet/alter_health()
	return get_turf(src)

/obj/structure/closet/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	if(air_group || (height == 0 || wall_mounted)) return 1
	return (!density)

/obj/structure/closet/proc/select_gamemode_equipment(gamemode)
	return

/obj/structure/closet/proc/can_open()
	if(src.welded)
		return 0
	return 1

/obj/structure/closet/proc/can_close()
	for(var/obj/structure/closet/closet in get_turf(src))
		if(closet != src && !closet.wall_mounted)
			return 0
	for(var/mob/living/carbon/Xenomorph/Xeno in get_turf(src))
		return 0
	return 1

/obj/structure/closet/proc/dump_contents()

	for(var/obj/I in src)
		I.forceMove(loc)

	for(var/mob/M in src)
		M.forceMove(loc)

/obj/structure/closet/proc/open()
	if(src.opened)
		return 0

	if(!src.can_open())
		return 0

	src.dump_contents()

	opened = 1
	update_icon()
	playsound(src.loc, open_sound, 15, 1)
	density = 0
	return 1

/obj/structure/closet/proc/close()
	if(!src.opened)
		return 0
	if(!src.can_close())
		return 0

	var/stored_units = 0
	if(store_items)
		stored_units = store_items(stored_units)
	if(store_mobs)
		stored_units = store_mobs(stored_units)

	opened = 0
	update_icon()

	playsound(src.loc, close_sound, 15, 1)
	density = 1
	return 1

/obj/structure/closet/proc/store_items(var/stored_units)
	for(var/obj/item/I in src.loc)
		var/item_size = Ceiling(I.w_class / 2)
		if(stored_units + item_size > storage_capacity)
			continue
		if(!I.anchored)
			I.loc = src
			stored_units += item_size
	return stored_units

/obj/structure/closet/proc/store_mobs(var/stored_units)
	for(var/mob/M in src.loc)
		if(stored_units + mob_size > storage_capacity)
			break
		if(istype (M, /mob/dead/observer))
			continue
		if(M.buckled)
			continue

		M.forceMove(src)
		stored_units += mob_size
	return stored_units

/obj/structure/closet/proc/toggle(mob/user)
	user.next_move = world.time + 5
	if(!(src.opened ? src.close() : src.open()))
		user << "<span class='notice'>It won't budge!</span>"
	return

// this should probably use dump_contents()
/obj/structure/closet/ex_act(severity)
	switch(severity)
		if(1)
			for(var/atom/movable/A as mob|obj in src)//pulls everything out of the locker and hits it with an explosion
				A.loc = src.loc
				A.ex_act(severity++)
			cdel(src)
		if(2)
			if(prob(50))
				for (var/atom/movable/A as mob|obj in src)
					A.loc = src.loc
					A.ex_act(severity++)
				cdel(src)
		if(3)
			if(prob(5))
				for(var/atom/movable/A as mob|obj in src)
					A.loc = src.loc
					A.ex_act(severity++)
				cdel(src)

/obj/structure/closet/bullet_act(var/obj/item/projectile/Proj)
	if(health > 999) return 1
	health -= round(Proj.damage*0.3)
	if(prob(30)) playsound(loc, 'sound/effects/metalhit.ogg', 25, 1)
	if(health <= 0)
		for(var/atom/movable/A as mob|obj in src)
			A.loc = src.loc
		spawn(1)
			playsound(loc, 'sound/effects/meteorimpact.ogg', 25, 1)
			cdel(src)

	return 1

/obj/structure/closet/attack_animal(mob/living/user as mob)
	if(user.wall_smash)
		visible_message("\red [user] destroys the [src]. ")
		for(var/atom/movable/A as mob|obj in src)
			A.loc = src.loc
		cdel(src)

/obj/structure/closet/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(src.opened)
		if(istype(W, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = W
			if(G.grabbed_thing)
				src.MouseDrop_T(G.grabbed_thing, user)      //act like they were dragged onto the closet
			return
		if(W.abstract)
			return 0
		if(istype(W, /obj/item/weapon/weldingtool))
			var/obj/item/weapon/weldingtool/WT = W
			if(!WT.remove_fuel(0,user))
				user << "<span class='notice'>You need more welding fuel to complete this task.</span>"
				return
			new /obj/item/stack/sheet/metal(src.loc)
			for(var/mob/M in viewers(src))
				M.show_message("<span class='notice'>\The [src] has been cut apart by [user] with [WT].</span>", 3, "You hear welding.", 2)
			cdel(src)
			return
		if(isrobot(user))
			return
		if(user.drop_held_item())
			W.forceMove(loc)
	else if(istype(W, /obj/item/weapon/packageWrap))
		return
	else if(istype(W, /obj/item/weapon/weldingtool))
		var/obj/item/weapon/weldingtool/WT = W
		if(!WT.remove_fuel(0,user))
			user << "<span class='notice'>You need more welding fuel to complete this task.</span>"
			return
		welded = !welded
		update_icon()
		for(var/mob/M in viewers(src))
			M.show_message("<span class='warning'>[src] has been [welded?"welded shut":"unwelded"] by [user.name].</span>", 3, "You hear welding.", 2)
	else
		src.attack_hand(user)
	return

/obj/structure/closet/MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
	if(istype(O, /obj/screen)) //Fix for HUD elements making their way into the world	-Pete
		return
	if(O.loc == user)
		return
	if(user.is_mob_incapacitated())
		return
	if((!(istype(O, /atom/movable)) || O.anchored || get_dist(user, src) > 1 || get_dist(user, O) > 1 || user.contents.Find(src)))
		return
	if(user.loc == null) //Just in case someone manages to get a closet into the blue light dimension, as unlikely as that seems
		return
	if(!istype(user.loc, /turf)) //Are you in a container/closet/pod/etc?
		return
	if(climbable && user == O)
		do_climb(user)
	if(!opened)
		return
	if(istype(O, /obj/structure/closet))
		return
	step_towards(O, loc)
	if(user != O)
		user.show_viewers("<span class='danger'>[user] stuffs [O] into [src]!</span>")
	add_fingerprint(user)
	return

/obj/structure/closet/relaymove(mob/user)
	if(!isturf(src.loc)) return
	if(user.is_mob_incapacitated(TRUE)) return
	user.next_move = world.time + 5

	if(!src.open())
		user << "<span class='notice'>It won't budge!</span>"
		if(!lastbang)
			lastbang = 1
			for (var/mob/M in hearers(src, null))
				M << text("<FONT size=[]>BANG, bang!</FONT>", max(0, 5 - get_dist(src, M)))
			spawn(30)
				lastbang = 0


/obj/structure/closet/attack_paw(mob/user as mob)
	return src.attack_hand(user)

/obj/structure/closet/attack_hand(mob/user as mob)
	src.add_fingerprint(user)
	src.toggle(user)

// tk grab then use on self
/obj/structure/closet/attack_self_tk(mob/user as mob)
	src.add_fingerprint(user)
	if(!src.toggle())
		usr << "<span class='notice'>It won't budge!</span>"

/obj/structure/closet/verb/verb_toggleopen()
	set src in oview(1)
	set category = "Object"
	set name = "Toggle Open"

	if(!usr.canmove || usr.stat || usr.is_mob_restrained())
		return

	if(ishuman(usr))
		src.add_fingerprint(usr)
		src.toggle(usr)
	else
		usr << "<span class='warning'>This mob type can't use this verb.</span>"

/obj/structure/closet/update_icon()//Putting the welded stuff in updateicon() so it's easy to overwrite for special cases (Fridges, cabinets, and whatnot)
	overlays.Cut()
	if(!opened)
		icon_state = icon_closed
		if(welded)
			overlays += "welded"
	else
		icon_state = icon_opened

/obj/structure/closet/hear_talk(mob/M as mob, text)
	for (var/atom/A in src)
		if(istype(A,/obj/))
			var/obj/O = A
			O.hear_talk(M, text)

/obj/structure/closet/proc/break_open()
	if(!opened)
		dump_contents()
		opened = 1
		playsound(loc, open_sound, 15, 1) //Could use a more telltale sound for "being smashed open"
		density = 0
		welded = 0
		update_icon()
