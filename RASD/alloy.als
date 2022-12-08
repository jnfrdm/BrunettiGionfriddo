open util/time

module eMallRASDAlloy

abstract sig User {
	username: one String
}

sig EndUser extends User {
	paymentMethod: set PaymentMethod,
	vehicle: set Vehicle,
	book: set Recharge
}

sig PaymentMethod { }

sig Vehicle {	
} {
	one this.~vehicle
}

sig Recharge {
	rechargeId: one Int,
	startTime: one Time,
	endTime: one Time,
	target: one Vehicle,
	payment: one PaymentMethod,
	currentStatus: one RechargeStatus,
	chargingSocket: one ChargingSocket
} {
	gt[endTime, startTime] && rechargeId > 2
} 

abstract sig RechargeStatus { }

one sig Booked, StartedCharging, EndedCharging, Paid extends RechargeStatus {}

sig ChargingSocket {
	type: one Int,
	chargingColumn: one ChargingColumn
} {
	//0 slow speed socket, 1 medium speed, 2 fast speed
	type >= 0 && type < 3
}

sig ChargingColumn {
	chargingStationC: one ChargingStation
} {
	some this.~chargingColumn
}

sig Battery {
	chargingStationB: one ChargingStation
}

sig ChargingStation {
	discount: one Discount,
	eMSP: one EMSP
} {
	some this.~chargingStationC
}

sig EMSP {}

abstract sig Discount { }

one sig Zero, TwenyFive, Fifty, Other extends Discount {}

sig CPO { }

sig CPOW extends User {
	badgeNumber: one Int,
	work: one CPO,
	cpms: one CPMS
} {
	badgeNumber > 5
}

sig CPMS {
	cpo: one CPO,
	dso: some DSO,
	manage: some ChargingStation,
	control: some EnergyFurniture
} {
	some this.~cpms
}

sig DSO {
	energyFurniture: set EnergyFurniture
}

sig EnergyFurniture {
	battery: lone Battery,
	chargingSocket: lone ChargingSocket
} {
	one this.~energyFurniture
}

fact usersPartition {EndUser + CPOW = User}

fact avoidDifferentUsersWithSameUsername {
	no disjoint u1, u2: User | u1.username = u2.username
}

fact avoidDifferentCPOWWithSameBadgeNumber {
	no disjoint c1, c2: CPOW | c1.badgeNumber = c2.badgeNumber
}

fact avoidDifferentRechargesWithSameId {
	no disjoint r1, r2: Recharge | r1.rechargeId = r2.rechargeId
}

fact allRechargeHasOneUser {
	all r: Recharge | one r.~book
}

// Ensure that the EndUser who books a recharge is also the one that owns the car related to that recharge 
fact rechargeHasUniqueEndUser {
	all r: Recharge | one v: Vehicle | one u: EndUser | u.book = r && r.target = v && v in u.vehicle
}

// If a user has a recharge he also must have a payment method
fact rechargeHasUniqueEndUser {
	all r: Recharge | one p: PaymentMethod | one u: EndUser | u.book = r && r.payment = p && p in u.paymentMethod
}

fact allCPOHasOneCPMS {
	all c: CPO | one c.~cpo
}

fact allChargingStationsHasOneCPMS {
	all c: ChargingStation | one c.~manage
}

fact allEnergyFurnitureHasOneCPMS {
	all e: EnergyFurniture | one e.~control
}

// Ensure that each CPOW is connected to the CPMS of his CPO 
fact cPOWAndCPMSameCPO {
	all w: CPOW | one i: CPMS | one c: CPO | w.work = c && w.cpms = i && i.cpo = c
}

// Ensure that an energy furniture is related to a battery or to a charging station but that can't be related to them both
fact energyFurnitureUniqueness {
	all e: EnergyFurniture | (e.battery != none && e.chargingSocket = none) or (e.battery = none && e.chargingSocket != none)
}

// Ensure that if an energyFurniture arrives to a battery must be controlled from the CPMS that manage the related charging station
fact energyFurnitureCoherenceBattery {
	all c: CPMS | all e: EnergyFurniture | all b: Battery | all s: ChargingStation | (e in c.control && e.battery = b && b.chargingStationB = s) 
implies s in c.manage
}

// Ensure that if an energyFurniture arrives to a chargingSocket must be controlled from the CPMS that manage the related charging station
fact energyFurnitureCoherenceChargingSocket {
	all c: CPMS | all e: EnergyFurniture | all t: ChargingSocket | all l: ChargingColumn 
| all s: ChargingStation | (e in c.control && e.chargingSocket = t && t.chargingColumn = l && l.chargingStationC = s) implies s in c.manage
}

// Ensure that if an EnergyFurniture comes from a DSO that DSO must be related with the CPMS that controls the EnergyFurniture
fact dSOCoherence {
	all d: DSO | all e: EnergyFurniture | all c: CPMS | (e in c.control && d in c.dso) implies e in d.energyFurniture
}

// Avoid different charges in the same timeframe in the same socket
fact avoidOverlapping {
	all r1, r2: Recharge | one s: ChargingSocket | 
(r1.chargingSocket = s && r2.chargingSocket = s) implies 
(((gt[r1.startTime, r2.startTime] && gt[r1.startTime, r2.endTime]) or (gt[r2.startTime, r1.endTime] && gt[r2.endTime, r1.endTime])) && (r2.startTime !=  r1.startTime && r2.endTime != r1.endTime))
}

// Ensure recharge state order coherence between different recharges
fact rechargeStatusCoherence {
	all r1, r2: Recharge | (gt[r2.startTime, r1.endTime] && r1.currentStatus != Paid) implies r2.currentStatus = Booked
}

fact stringPool {
	none != "a" + "b" + "c" + "d" + "e"
}

pred userAddVehicle [u, u': EndUser, v: Vehicle] {
	u'.vehicle = u.vehicle + v	
}

pred userBookCharge [u, u':EndUser, r: Recharge, v: Vehicle, t1: Time, t2: Time, c: ChargingSocket, p: PaymentMethod, s: Booked] {
	r.target = v
	r.startTime = t1
	r.endTime = t2
	r.chargingSocket = c
	r.currentStatus = s
	u'.book = u.book + r
}

pred startCharging [r, r': Recharge, s: StartedCharging] {
	r'.currentStatus = s
}

pred provideEnergyFurnitureToBattery [c, c': CPMS, d: DSO, e: EnergyFurniture, b: Battery] {
	c'.dso = c.dso + d
	d.energyFurniture = e
	e.battery = b
}

run provideEnergyFurnitureToBattery

pred world1 {
	#EndUser = 2
	#PaymentMethod = 2
	#Vehicle = 3
	#Recharge > 1
	#ChargingSocket > 1
	#ChargingColumn > 1
	#eMSP < 2
}

pred world2 {
	#CPOW > 1
	#CPMS = 2
	#DSO > 1
	#EnergyFurniture = 5
	#ChargingSocket > 2
	#Battery = 3
	#ChargingStation = 3
	some e: EnergyFurniture | e.chargingSocket != none
	some e: EnergyFurniture | e.battery != none
}

//run world1 for 5

//run world2 for 5
